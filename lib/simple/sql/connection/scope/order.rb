class Simple::SQL::Connection::Scope
  def order_by(sql_fragment)
    duplicate.send(:order_by!, sql_fragment)
  end

  def limit(limit)
    raise ArgumentError, "limit must be >= 0" unless limit >= 0

    duplicate.send(:limit!, limit)
  end

  def offset(offset)
    raise ArgumentError, "offset must be >= 0" unless offset >= 0

    duplicate.send(:offset!, offset)
  end

  private

  # Adjust sort order
  def order_by!(sql_fragment)
    @order_by_fragment = sql_fragment
    self
  end

  # Adjust sort order
  def limit!(count)
    @limit = count
    self
  end

  def offset!(offset)
    @offset = offset
    self
  end

  # called from to_sql
  def apply_order_and_limit(sql)
    sql = "#{sql} ORDER BY #{@order_by_fragment}" if @order_by_fragment
    sql = "#{sql} LIMIT #{@limit}" if @limit
    sql = "#{sql} OFFSET #{@offset}" if @offset

    sql
  end
end
