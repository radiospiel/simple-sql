# rubocop:disable Metrics/AbcSize
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

  # returns the total_count of search hits
  #
  # This is filled in when resolving a paginated scope.
  attr_reader :total_count

  # returns the total number of pages of search hits
  #
  # This is filled in when resolving a paginated scope. It takes
  # into account the scope's "per" option.
  attr_reader :total_pages

  # returns the current page number in a paginated search
  #
  # This is filled in when resolving a paginated scope.
  attr_reader :current_page

  private

  def set_pagination_info(scope)
    raise ArgumentError, "per must be > 0" unless scope.per > 0

    if scope.page <= 1 && empty?
      # This branch is an optimization: the call to the database to count is
      # not necessary if we know that there are not even any results on the
      # first page.
      @total_count  = 0
      @current_page = 1
    else
      sql = "SELECT COUNT(*) FROM (#{scope.order_by(nil).to_sql(pagination: false)}) simple_sql_count"
      @total_count = ::Simple::SQL.ask(sql, *scope.args)
      @current_page = scope.page
    end

    @total_pages = (@total_count * 1.0 / scope.per).ceil
  end
end
