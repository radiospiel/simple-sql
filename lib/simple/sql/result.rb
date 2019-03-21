# rubocop:disable Naming/AccessorMethodName

require_relative "helpers"

class ::Simple::SQL::Result < Array
end

require_relative "result/records"

# The result of SQL.all
#
# This class implements the basic interface of a Result set. Record result sets
# support the conversion of a record into a custom type of the callers choice,
# via the :into option for <tt>SQL.all</tt> and <tt>SQL.ask</tt>.
#
#
class ::Simple::SQL::Result < Array
  # A Result object is requested via ::Simple::SQL::Result.build, which then
  # chooses the correct implementation, based on the <tt>target_type:</tt>
  # parameter.
  def self.build(records, target_type:, pg_source_oid:) # :nodoc:
    if target_type.nil?
      new(records)
    else
      Records.new(records, target_type: target_type, pg_source_oid: pg_source_oid)
    end
  end

  def initialize(records) # :nodoc:
    replace(records)
  end

  # returns a fast estimate for the total_count of search hits
  #
  # This is filled in when resolving a paginated scope.
  def total_count_estimate
    @total_count_estimate ||= catch(:total_count_estimate) do
      scope = @pagination_scope
      scope_sql = scope.order_by(nil).to_sql(pagination: false)
      ::Simple::SQL.each("EXPLAIN #{scope_sql}", *scope.args) do |line|
        next unless line =~ /\brows=(\d+)/

        throw :total_count_estimate, Integer($1)
      end
      -1
    end
  end

  # returns the estimated total number of pages of search hits
  #
  # This is filled in when resolving a paginated scope.
  def total_pages_estimate
    @total_pages_estimate ||= (total_count_estimate * 1.0 / @pagination_scope.per).ceil
  end

  # returns the total_count of search hits
  #
  # This is filled in when resolving a paginated scope.
  def total_count
    @total_count ||= begin
      scope = @pagination_scope
      scope_sql = scope.order_by(nil).to_sql(pagination: false)
      ::Simple::SQL.ask("SELECT COUNT(*) FROM (#{scope_sql}) simple_sql_count", *scope.args)
    end
  end

  # returns the total number of pages of search hits
  #
  # This is filled in when resolving a paginated scope. It takes
  # into account the scope's "per" option.
  def total_pages
    @total_pages ||= (total_count * 1.0 / @pagination_scope.per).ceil
  end

  # returns the current page number in a paginated search
  #
  # This is filled in when resolving a paginated scope.
  def current_page
    @current_page ||= @pagination_scope.page
  end

  private

  def set_pagination_info(scope)
    raise ArgumentError, "per must be > 0" unless scope.per > 0

    if scope.page <= 1 && empty?
      # This branch is an optimization: the call to the database to count is
      # not necessary if we know that there are not even any results on the
      # first page.
      @current_page = 1
      @total_count  = 0
      @total_pages  = 1
      @total_count_estimate  = 0
      @total_pages_estimate  = 1
    else
      @pagination_scope = scope
    end
  end
end
