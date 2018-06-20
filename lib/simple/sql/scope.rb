# rubocop:disable Style/MultipleComparison

require_relative "scope/filters.rb"
require_relative "scope/order.rb"
require_relative "scope/pagination.rb"

# The Simple::SQL::Scope class helps building scopes; i.e. objects
# that start as a quite basic SQL query, and allow one to add
# sql_fragments as where conditions.
class Simple::SQL::Scope
  SELF = self

  attr_reader :args
  attr_reader :per, :page

  # Build a scope object
  def initialize(sql)
    @sql = sql
    @args = []
    @filters = []
    @order_by = nil
  end

  private

  def duplicate
    dupe = SELF.new(@sql)
    dupe.instance_variable_set :@args, @args.dup
    dupe.instance_variable_set :@filters, @filters.dup
    dupe.instance_variable_set :@per, @per
    dupe.instance_variable_set :@page, @page
    dupe.instance_variable_set :@order_by_fragment, @order_by_fragment
    dupe
  end

  public

  # generate a sql query
  def to_sql(pagination: :auto)
    raise ArgumentError unless pagination == :auto || pagination == false

    sql = @sql
    sql = apply_filters(sql)
    sql = apply_order(sql)
    sql = apply_pagination(sql, pagination: pagination)

    sql
  end

  # The Scope::PageInfo module can be mixed into other objects to
  # hold total_count, total_pages, and current_page.
  module PageInfo
    attr_reader :total_count, :total_pages, :current_page

    def self.attach(results, total_count:, per:, page:)
      results.extend(self)
      results.instance_variable_set :@total_count, total_count
      results.instance_variable_set :@total_pages, (total_count + (per - 1)) / per
      results.instance_variable_set :@current_page, page
      results
    end
  end
end
