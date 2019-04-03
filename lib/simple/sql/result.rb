# rubocop:disable Style/DoubleNegation
# rubocop:disable Style/GuardClause

require_relative "helpers"

class ::Simple::SQL::Result < Array
  attr_accessor :column_info
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
  def self.build(connection, records, target_type:, pg_source_oid:) # :nodoc:
    if target_type.nil?
      new(connection, records)
    else
      Records.new(connection, records, target_type: target_type, pg_source_oid: pg_source_oid)
    end
  end

  attr_reader :connection

  def initialize(connection, records) # :nodoc:
    @connection = connection
    replace(records)
  end

  # returns the (potentialy estimated) total count of results
  #
  # This is only available for paginated scopes
  def total_fast_count
    @total_fast_count ||= pagination_scope.fast_count
  end

  # returns the (potentialy estimated) total number of pages
  #
  # This is only available for paginated scopes
  def total_fast_pages
    @total_fast_pages ||= (total_fast_count * 1.0 / pagination_scope.per).ceil
  end

  # returns the (potentialy slow) exact total count of results
  #
  # This is only available for paginated scopes
  def total_count
    @total_count ||= pagination_scope.count
  end

  # returns the (potentialy estimated) total number of pages
  #
  # This is only available for paginated scopes
  def total_pages
    @total_pages ||= (total_count * 1.0 / pagination_scope.per).ceil
  end

  # returns the current page number in a paginated search
  #
  # This is only available for paginated scopes
  def current_page
    @current_page ||= pagination_scope.page
  end

  def paginated?
    !!@pagination_scope
  end

  def pagination_scope
    raise "Only available only for paginated scopes" unless paginated?

    @pagination_scope
  end

  def pagination_scope=(scope)
    raise ArgumentError, "per must be > 0" unless scope.per > 0

    @pagination_scope = scope

    # This branch is an optimization: the call to the database to count is
    # not necessary if we know that there are not even any results on the
    # first page.
    if scope.page <= 1 && empty?
      @current_page = 1
      @total_count  = 0
      @total_pages  = 1
      @total_fast_count  = 0
      @total_fast_pages  = 1
    end
  end
end
