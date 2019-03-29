# This module implements an adapter between the Simple::SQL interface
# (i.e. ask, all, first, transaction) and a raw connection.
#
# This module can be mixed onto objects that implement a raw_connection
# method, which must return a Pg::Connection.

module Simple::SQL::ConnectionAdapter
  Logging = ::Simple::SQL::Logging
  Scope   = ::Simple::SQL::Scope

  # execute one or more sql statements. This method does not allow to pass in
  # arguments - since the pg client does not support this - but it allows to
  # run multiple sql statements separated by ";"
  def exec(sql)
    Logging.with_logged_query sql do
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

    rows = []
    my_pg_source_oid = nil

    each_without_conversion(sql, *args, into: into) do |row, pg_source_oid|
      rows << row
      my_pg_source_oid = pg_source_oid
    end

    record_set = convert_rows_to_result rows, into: into, pg_source_oid: my_pg_source_oid

    # [TODO] - resolve associations. Note that this is only possible if the type
    # is not an Array (i.e. into is nil)

    if sql.is_a?(Scope) && sql.paginated?
      record_set.send(:set_pagination_info, sql)
    end

    record_set
  end

  def each(sql, *args, into: nil)
    raise ArgumentError, "Missing block" unless block_given?

    each_without_conversion sql, *args, into: into do |row, pg_source_oid|
      record = convert_row_to_record row, into: into, pg_source_oid: pg_source_oid
      yield record
    end

    self
  end

  # Runs a query and prints the results via "table_print"
  def print(sql, *args, into: nil)
    raise ArgumentError, "You cannot call Simple::SQL.print with into: #{into.inspect}" unless into.nil?

    require "table_print"
    records = all sql, *args, into: Hash
    tp records
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
  def costs(sql, *args)
    explanation_first = Simple::SQL.ask "EXPLAIN #{sql}", *args
    unless explanation_first =~ /cost=(\d+(\.\d+))\.+(\d+(\.\d+))/
      raise "Cannot determine cost"
    end

    [Float($1), Float($3)]
  end

  # Executes a block, usually of db insert code, while holding an
  # advisory lock.
  #
  # Examples:
  #
  # - <tt>Simple::SQL.locked(4711) { puts 'do work while locked' }
  def locked(lock_id)
    ask("SELECT pg_advisory_lock(#{lock_id})")
    yield
  ensure
    ask("SELECT pg_advisory_unlock(#{lock_id})")
  end

  private

  Result = ::Simple::SQL::Result
  Decoder = ::Simple::SQL::Helpers::Decoder
  Encoder = ::Simple::SQL::Helpers::Encoder

  def exec_logged(sql_or_scope, *args)
    if sql_or_scope.is_a?(Scope)
      raise ArgumentError, "You cannot call .all with a scope and additional arguments" unless args.empty?

      sql  = sql_or_scope.to_sql
      args = sql_or_scope.args
    else
      sql = sql_or_scope
    end

    Logging.with_logged_query sql, *args do
      raw_connection.exec_params(sql, Encoder.encode_args(raw_connection, args))
    end
  end

  def each_without_conversion(sql, *args, into: nil)
    pg_result = exec_logged(sql, *args)

    if pg_result.ntuples > 0 && pg_result.nfields > 0
      decoder = Decoder.new(self, pg_result, into: (into ? Hash : nil))
      pg_source_oid = pg_result.ftable(0)

      pg_result.each_row do |row|
        yield decoder.decode(row), pg_source_oid
      end
    end

    # optimization: If we wouldn't clear here the GC would do this later.
    pg_result.clear unless pg_result.autoclear?
  end

  def convert_row_to_record(row, into:, pg_source_oid:)
    convert_rows_to_result([row], into: into, pg_source_oid: pg_source_oid).first
  end

  def convert_rows_to_result(rows, into:, pg_source_oid:)
    Result.build(self, rows, target_type: into, pg_source_oid: pg_source_oid)
  end

  public

  def resolve_type(ftype, fmod)
    @resolved_types ||= {}
    @resolved_types[[ftype, fmod]] ||= raw_connection.exec("SELECT format_type($1,$2)", [ftype, fmod]).getvalue(0, 0)
  end
end
