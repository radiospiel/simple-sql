

class Simple::SQL::Scope
  def order_by(sql_fragment)
    duplicate.send(:order_by!, sql_fragment)
  end

  def limit(count)
    duplicate.send(:limit!, count)
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

  # called from to_sql
  def apply_order_and_limit(sql)
    sql = "#{sql} ORDER BY #{@order_by_fragment}" if @order_by_fragment
    sql = "#{sql} LIMIT #{@limit}" if @limit

    sql
  end
end
