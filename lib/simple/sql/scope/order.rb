

class Simple::SQL::Scope
  def order_by(sql_fragment)
    duplicate.send(:order_by!, sql_fragment)
  end

  private

  # Adjust sort order
  def order_by!(sql_fragment)
    @order_by_fragment = sql_fragment
    self
  end

  # called from to_sql
  def apply_order(sql)
    return sql unless @order_by_fragment
    "#{sql} ORDER BY #{@order_by_fragment}"
  end
end
