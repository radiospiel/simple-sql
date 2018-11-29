# rubocop:disable Style/IfUnlessModifier

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
    Logging.yield_logged sql do
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
    pg_result = exec_logged(sql, *args)

    # enumerate the rows in pg_result. This returns either an Array of Hashes
    # (if into is set), or an array of row arrays or of singular values.
    #
    # Even if into is set to something different than a Hash, we'll convert
    # each row into a Hash initially, and only later convert it to the final
    # target type (via RowConverter.convert_ary). This is to allow to fill in
    # more entries later on.
    records = enumerate(pg_result, into: into)

    # optimization: If we wouldn't clear here the GC would do this later.
    pg_result.clear unless pg_result.autoclear?

    # [TODO] - resolve associations. Note that this is only possible if the type
    # is not an Array (i.e. into is nil)

    if sql.is_a?(Scope) && sql.paginated?
      records.send(:set_pagination_info, sql)
    end

    records.each(&block) if block
    records
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
      all(sql, *args, into: into) { |row| throw :ok, row }
      nil
    end
  end

  # Executes a block, usually of db insert code, while holding an
  # advisory lock.
  #
  # Examples:
  #
  # - <tt>Simple::SQL.locked(4711) { puts 'do work while locked' }
  def locked(lock_id)
    begin
      ask("SELECT pg_advisory_lock(#{lock_id})")
      yield
    ensure
      ask("SELECT pg_advisory_unlock(#{lock_id})")
    end
  end

  private

  Encoder = ::Simple::SQL::Helpers::Encoder

  def exec_logged(sql_or_scope, *args)
    if sql_or_scope.is_a?(Scope)
      raise ArgumentError, "You cannot call .all with a scope and additional arguments" unless args.empty?

      sql  = sql_or_scope.to_sql
      args = sql_or_scope.args
    else
      sql = sql_or_scope
    end

    Logging.yield_logged sql, *args do
      raw_connection.exec_params(sql, Encoder.encode_args(raw_connection, args))
    end
  end

  Result = ::Simple::SQL::Result
  Decoder = ::Simple::SQL::Helpers::Decoder

  def enumerate(pg_result, into:)
    records = []
    pg_source_oid = nil

    if pg_result.ntuples > 0 && pg_result.nfields > 0
      decoder = Decoder.new(self, pg_result, into: (into ? Hash : nil))
      pg_result.each_row { |row| records << decoder.decode(row) }
      pg_source_oid = pg_result.ftable(0)
    end

    Result.build(records, target_type: into, pg_source_oid: pg_source_oid)
  end

  public

  def resolve_type(ftype, fmod)
    @resolved_types ||= {}
    @resolved_types[[ftype, fmod]] ||= raw_connection.exec("SELECT format_type($1,$2)", [ftype, fmod]).getvalue(0, 0)
  end
end
