# rubocop:disable Metrics/AbcSize

# This module implements an adapter between the Simple::SQL interface
# (i.e. ask, all, first, transaction) and a raw connection.
#
# This module can be mixed onto objects that implement a raw_connection
# method, which must return a Pg::Connection.

class Simple::SQL::Connection
  Logging = ::Simple::SQL::Logging

  # execute one or more sql statements. This method does not allow to pass in
  # arguments - since the pg client does not support this - but it allows to
  # run multiple sql statements separated by ";"
  def exec(sql)
    Logging.with_logged_query self, sql do
      raw_connection.exec sql
    end
  end

  # Runs a query, with optional arguments, and returns the result. If the SQL
  # query returns rows with one column, this method returns an array of these
  # values. Otherwise it returns an array of arrays.
  #
  # Example:
  #
  # - <tt>Simple::SQL.all("SELECT id FROM users")</tt> returns an array of id values
  # - <tt>Simple::SQL.all("SELECT id, email FROM users")</tt> returns an array of
  #         arrays `[ <id>, <email> ]`.
  #
  # Simple::SQL.all "SELECT id, email FROM users" do |id, email|
  #   # do something
  # end

  def all(sql, *args, into: nil, &block)
    raise ArgumentError, "all no longer support blocks, use each instead." if block

    rows, pg_source_oid, column_info = each_without_conversion(sql, *args, into: into)

    result = convert_rows_to_result rows, into: into, pg_source_oid: pg_source_oid

    # [TODO] - resolve associations. Note that this is only possible if the type
    # is not an Array (i.e. into is nil)

    result.pagination_scope = sql if sql.is_a?(::Simple::SQL::Connection::Scope) && sql.paginated?
    result.column_info      = column_info
    result
  end

  def each(sql, *args, into: nil)
    raise ArgumentError, "Missing block" unless block_given?

    rows, pg_source_oid, _column_info = each_without_conversion sql, *args, into: into

    rows.each do |row|
      record = convert_rows_to_result([row], into: into, pg_source_oid: pg_source_oid).first
      yield record
    end

    self
  end

  # Runs a query and prints the results via "table_print"
  def print(sql, *args, io: STDOUT, width: :auto)
    if sql.is_a?(Array) && args.empty?
      records = sql
    else
      records = all sql, *args, into: Hash
    end

    ::Simple::SQL.table_print(records, width: width, io: io)
    records
  end

  # Runs a query and returns the first result row of a query.
  #
  # Examples:
  #
  # - <tt>Simple::SQL.ask "SELECT id FROM users WHERE email=$?", "foo@local"</tt>
  #   returns a number (or +nil+)
  # - <tt>Simple::SQL.ask "SELECT id, email FROM users WHERE email=$?", "foo@local"</tt>
  #   returns an array <tt>[ <id>, <email> ]</tt> (or +nil+)
  def ask(sql, *args, into: nil)
    catch(:ok) do
      each(sql, *args, into: into) { |row| throw :ok, row }
      nil
    end
  end

  # returns an Array [min_cost, max_cost] based on the database's estimation
  def estimate_cost(sql, *args)
    explanation = ask "EXPLAIN (FORMAT JSON) #{sql}", *args
    explanation.first.dig "Plan", "Total Cost"
  end

  private

  Result = ::Simple::SQL::Result
  Decoder = ::Simple::SQL::Helpers::Decoder
  Encoder = ::Simple::SQL::Helpers::Encoder

  def exec_logged(sql_or_scope, *args)
    if sql_or_scope.is_a?(::Simple::SQL::Connection::Scope)
      raise ArgumentError, "You cannot call .all with a scope and additional arguments" unless args.empty?
      raise ArgumentError, "You cannot execute a scope on a different connection" unless self == sql_or_scope.connection

      sql  = sql_or_scope.to_sql
      args = sql_or_scope.args
    else
      sql = sql_or_scope
    end

    Logging.with_logged_query self, sql, *args do
      result_format = 0 # 0: text, 1: binary

      with_custom_type_map do
        raw_connection.exec_params(sql, Encoder.encode_args(raw_connection, args), result_format)
      end
    end
  rescue PG::InvalidTextRepresentation
    raise ArgumentError, $!.to_s
  end

  def with_custom_type_map
    # The "pg" gem comes with a set of Type mappers to convert between database
    # responses and the ruby representation. This would make things faster, 
    # especially with timestamp columns.

    old_type_map_for_results = raw_connection.type_map_for_results
    raw_connection.type_map_for_results = custom_type_map_for_results

    yield
  ensure
    raw_connection.type_map_for_results = old_type_map_for_results
  end

  def custom_type_map_for_results
    @custom_type_map_for_results ||= begin
      type_map = PG::BasicTypeMapForResults.new(raw_connection)

      type_map.add_coder TextDecoder::HStore.new(name: "hstore", oid: -1) # hstore
      # type_map.add_coder BinaryDecoder::JSON.new(name: "json", oid: 114)   # json
      # type_map.add_coder BinaryDecoder::JSON.new(name: "jsonb", oid: 3802)  # jsonb
      
      # binding.pry
      type_map
    end
  end

  module TextDecoder
    class HStore < PG::SimpleDecoder
      def format
        0
      end

      def decode(string, tuple=nil, field=nil)
        # ::JSON.load(string)
        "hsotr"
      end
    end
  end
  
    module BinaryDecoder
      class JSON < PG::SimpleDecoder
        def format
          1
        end

        def decode(string, tuple=nil, field=nil)
          ::JSON.load(string)
        end
      end
    end
  

  # returns an array of decoded entries, if any
  def each_without_conversion(sql, *args, into: nil)
    pg_result = exec_logged(sql, *args)

    column_info = collect_column_info(pg_result)
    rows = []
    pg_source_oid = nil

    if pg_result.ntuples > 0 && pg_result.nfields > 0
      decoder = Decoder.new(pg_result, into: (into ? Hash : nil), column_info: column_info)
      pg_source_oid = pg_result.ftable(0)

      pg_result.each_row do |row|
        rows << decoder.decode(row)
      end
    end

    [rows, pg_source_oid, column_info]
  ensure
    # optimization: If we wouldn't clear here the GC would do this later.
    pg_result.clear if pg_result && !pg_result.autoclear?
  end

  def collect_column_info(pg_result)
    return unless pg_result.nfields > 0

    (0...pg_result.nfields).map do |idx|
      ftype = pg_result.ftype(idx)
      fmod = pg_result.fmod(idx)

      {
        name: pg_result.fname(idx).to_sym,
        pg_type_name: type_info.pg_type_name(ftype: ftype, fmod: fmod),
        type_name: type_info.type_name(ftype: ftype, fmod: fmod)
      }
    end
  end

  def convert_rows_to_result(rows, into:, pg_source_oid:)
    Result.build(self, rows, target_type: into, pg_source_oid: pg_source_oid)
  end
end
