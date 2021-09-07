class Simple::SQL::Connection::Scope
  EXACT_COUNT_THRESHOLD = 10_000

  # Returns the exact count of matching records
  def count
    sql = order_by(nil).to_sql(pagination: false)

    @connection.ask("SELECT COUNT(*) FROM (#{sql}) _total_count", *args)
  end

  # Returns the fast count of matching records
  #
  # For counts larger than EXACT_COUNT_THRESHOLD this returns an estimate
  def count_estimate
    estimate = estimated_count
    return estimate if estimate > EXACT_COUNT_THRESHOLD

    sql = order_by(nil).to_sql(pagination: false)
    @connection.ask("SELECT COUNT(*) FROM (#{sql}) _total_count", *args)
  end

  # returns the query plan as a Hash.
  def explain
    sql = to_sql(pagination: false)
    explanation = @connection.ask("EXPLAIN (FORMAT JSON) #{sql}", *args).first || {}
    explanation["Plan"]
  end

  private

  def estimated_count
    order_by(nil).explain.fetch("Plan Rows", -1)
  end
end
