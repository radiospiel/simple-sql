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

  private

  def estimated_count
    sql = order_by(nil).to_sql(pagination: false)
    lines = @connection.all("EXPLAIN #{sql}", *args)
    lines.each do |line|
      next unless line =~ /\brows=(\d+)/

      return Integer($1)
    end

    -1
  end
end
