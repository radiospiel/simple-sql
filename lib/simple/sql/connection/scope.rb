# rubocop:disable Style/MultipleComparison

require_relative "scope/shorthand"
require_relative "scope/where"
require_relative "scope/search"
require_relative "scope/order"
require_relative "scope/pagination"
require_relative "scope/count"
require_relative "scope/count_by_groups"

class Simple::SQL::Connection
  # Build a scope object
  #
  # This call supports a few variants:
  #
  #     Simple::SQL.scope("SELECT * FROM mytable")
  #     Simple::SQL.scope(table: "mytable", select: "*")
  #
  # The second option also allows one to pass in more options, like the following:
  #
  #     Simple::SQL.scope(table: "mytable", select: "*", where: { id: 1, foo: "bar" }, order_by: "id desc")
  #
  def scope(sql, args = [])
    ::Simple::SQL::Connection::Scope.new sql, args, connection: self
  end
end

# The Simple::SQL::Connection::Scope class helps building scopes; i.e. objects
# that start as a quite basic SQL query, and allow one to add
# sql_fragments as where conditions.
class Simple::SQL::Connection::Scope
  SELF = self

  attr_reader :connection, :args, :per, :page

  # when initialized with a Hash: contains table name
  attr_accessor :table_name

  def initialize(sql, args = [], connection:) # :nodoc:
    expect! sql => [String, Hash]

    @connection = connection

    @sql   = nil
    @args  = args
    @where = []

    case sql
    when String then @sql = sql
    when Hash then initialize_from_hash(sql)
    end
  end

  private

  # rubocop:disable Metrics/AbcSize
  def initialize_from_hash(hsh)
    actual_keys = hsh.keys
    valid_keys = [:table, :select, :where, :order_by]
    extra_keys = actual_keys - valid_keys
    raise ArgumentError, "Extra keys #{extra_keys.inspect}; allowed are #{valid_keys.inspect}" unless extra_keys.empty?

    # -- set table and select -------------------------------------------------

    @table_name = hsh[:table] || raise(ArgumentError, "Missing :table option")
    select = hsh[:select] || "*"

    @sql = "SELECT #{Array(select).join(', ')} FROM #{table_name}"

    # -- apply conditions, if any ---------------------------------------------

    where!(hsh[:where]) unless hsh[:where].nil?
    order_by!(hsh[:order_by]) unless hsh[:order_by].nil?
  end

  def duplicate
    dupe = SELF.new(@sql, connection: @connection)
    dupe.instance_variable_set :@table_name, @table_name.dup
    dupe.instance_variable_set :@args, @args.dup
    dupe.instance_variable_set :@where, @where.dup
    dupe.instance_variable_set :@per, @per
    dupe.instance_variable_set :@page, @page
    dupe.instance_variable_set :@order_by_fragment, @order_by_fragment
    dupe.instance_variable_set :@limit, @limit
    dupe.instance_variable_set :@offset, @offset
    dupe
  end

  public

  # generate a sql query
  def to_sql(pagination: :auto)
    raise ArgumentError unless pagination == :auto || pagination == false

    sql = @sql
    sql = apply_where(sql)
    sql = apply_order_and_limit(sql)
    sql = apply_pagination(sql, pagination: pagination)

    sql
  end
end
