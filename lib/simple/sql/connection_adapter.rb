# rubocop:disable Style/IfUnlessModifier
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

# This module implements an adapter between the Simple::SQL interface
# (i.e. ask, all, first, transaction) and a raw connection.
#
# This module can be mixed onto objects that implement a raw_connection
# method, which must return a Pg::Connection.
module Simple::SQL::ConnectionAdapter
  Logging = ::Simple::SQL::Logging
  Encoder = ::Simple::SQL::Encoder
  Decoder = ::Simple::SQL::Decoder
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
    result = exec_logged(sql, *args)
    result = enumerate(result, into: into, &block)
    if sql.is_a?(Scope) && sql.paginated?
      add_page_info(sql, result)
    end
    result
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

  private

  def add_page_info(scope, results)
    raise ArgumentError, "expect Array but get a #{results.class.name}" unless results.is_a?(Array)
    raise ArgumentError, "per must be > 0" unless scope.per > 0

    # optimization: add empty case (page <= 1 && results.empty?)
    if scope.page <= 1 && results.empty?
      Scope::PageInfo.attach(results, total_count: 0, per: scope.per, page: 1)
    else
      sql = "SELECT COUNT(*) FROM (#{scope.order_by(nil).to_sql(pagination: false)}) simple_sql_count"
      total_count = ask(sql, *scope.args)
      Scope::PageInfo.attach(results, total_count: total_count, per: scope.per, page: scope.page)
    end
  end

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

  def enumerate(result, into:, &block)
    decoder = Decoder.new(self, result, into: into)

    if block
      result.each_row do |row|
        yield decoder.decode(row)
      end
      self
    else
      ary = []
      result.each_row { |row| ary << decoder.decode(row) }
      ary
    end
  end

  public

  def resolve_type(ftype, fmod)
    @resolved_types ||= {}
    @resolved_types[[ftype, fmod]] ||= raw_connection.exec("SELECT format_type($1,$2)", [ftype, fmod]).getvalue(0, 0)
  end
end
