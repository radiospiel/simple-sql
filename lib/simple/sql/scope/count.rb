class Simple::SQL::Scope
  EXACT_COUNT_THRESHOLD = 10_000

  # Returns the exact count of matching records
  def count
    sql = order_by(nil).to_sql(pagination: false)
    ::Simple::SQL.ask("SELECT COUNT(*) FROM (#{sql}) _total_count", *args)
  end

  # Returns the fast count of matching records
  #
  # For counts larger than EXACT_COUNT_THRESHOLD this returns an estimate
  def fast_count
    estimate = estimated_count
    return estimate if estimate > EXACT_COUNT_THRESHOLD

    sql = order_by(nil).to_sql(pagination: false)
    ::Simple::SQL.ask("SELECT COUNT(*) FROM (#{sql}) _total_count", *args)
  end

  private

  def estimated_count
    sql = order_by(nil).to_sql(pagination: false)
    ::Simple::SQL.each("EXPLAIN #{sql}", *args) do |line|
      next unless line =~ /\brows=(\d+)/

      return Integer($1)
    end

    -1
  end
end
