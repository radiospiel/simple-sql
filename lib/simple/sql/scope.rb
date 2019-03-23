# rubocop:disable Style/MultipleComparison

require_relative "scope/filters.rb"
require_relative "scope/order.rb"
require_relative "scope/pagination.rb"
require_relative "scope/count.rb"

# The Simple::SQL::Scope class helps building scopes; i.e. objects
# that start as a quite basic SQL query, and allow one to add
# sql_fragments as where conditions.
class Simple::SQL::Scope
  SELF = self

  attr_reader :args
  attr_reader :per, :page

  # Build a scope object
  #
  # This call supports a few variants:
  #
  #     Simple::SQL::Scope.new("SELECT * FROM mytable")
  #     Simple::SQL::Scope.new(table: "mytable", select: "*")
  #
  # The second option also allows one to pass in more options, like the following:
  #
  #     Simple::SQL::Scope.new(table: "mytable", select: "*", where: { id: 1, foo: "bar" }, order_by: "id desc")
  #
  def initialize(sql, args = [])
    expect! sql => [String, Hash]

    @sql     = nil
    @args    = args
    @filters = []

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

    table = hsh[:table] || raise(ArgumentError, "Missing :table option")
    select = hsh[:select] || "*"

    @sql = "SELECT #{Array(select).join(', ')} FROM #{table}"

    # -- apply conditions, if any ---------------------------------------------

    where!(hsh[:where]) unless hsh[:where].nil?
    order_by!(hsh[:order_by]) unless hsh[:order_by].nil?
  end

  def duplicate
    dupe = SELF.new(@sql)
    dupe.instance_variable_set :@args, @args.dup
    dupe.instance_variable_set :@filters, @filters.dup
    dupe.instance_variable_set :@per, @per
    dupe.instance_variable_set :@page, @page
    dupe.instance_variable_set :@order_by_fragment, @order_by_fragment
    dupe.instance_variable_set :@limit, @limit
    dupe
  end

  public

  # generate a sql query
  def to_sql(pagination: :auto)
    raise ArgumentError unless pagination == :auto || pagination == false

    sql = @sql
    sql = apply_filters(sql)
    sql = apply_order_and_limit(sql)
    sql = apply_pagination(sql, pagination: pagination)

    sql
  end
end
