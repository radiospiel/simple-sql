# rubocop:disable Metrics/AbcSize
# rubocop:disable Naming/AccessorMethodName

class ::Simple::SQL::Result::Rows < ::Simple::SQL::Result
  def initialize(records)
    replace(records)
  end

  # -- pagination info ------------------------------------------------------

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
