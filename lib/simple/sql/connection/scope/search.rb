# rubocop:disable Metrics/AbcSize
class Simple::SQL::Connection::Scope
  def search(filters, dynamic_column: nil, table_name: nil)
    table_name ||= self.table_name
    raise "Cannot run search without a table_name setting. Please set table_name on this scope." unless table_name

    column_types = connection.reflection.column_types(table_name)
    dynamic_column ||= column_types.detect { |_column_name, column_type| column_type == "jsonb" }.first

    Search.search(self, filters, dynamic_column: dynamic_column, column_types: column_types)
  end
end

module Simple::SQL::Connection::Scope::Search
  extend self

  ID_REGEXP = /\A[_a-zA-Z][_a-zA-Z0-9]*\z/

  # apply the filter hash onto the passed in scope. This matches all filters
  # with a name which is matching a column name against the column values.
  # It matches every other filter value against an entry in the
  # dynamic_filter column.
  def search(scope, filters, dynamic_column:, column_types:)
    expect! filters => [nil, Hash]
    expect! dynamic_column => ID_REGEXP

    filters.each_key do |key|
      expect! key => [Symbol, String]
      expect! key.to_s => ID_REGEXP
    end

    return scope if filters.nil? || filters.empty?

    # some filters try to match against existing columns, some try to match
    # against the "tags" JSONB column - and they result in different where
    # clauses in the Simple::SQL scope ("value = <match>" or "tags->>value = <match>").
    static_filters, dynamic_filters = filters.partition { |key, _| static_filter?(column_types, key) }

    scope = apply_static_filters(scope, static_filters, column_types: column_types)
    scope = apply_dynamic_filters(scope, dynamic_filters, dynamic_column: dynamic_column)
    scope
  end

  private

  def static_filter?(column_types, key)
    column_types.key?(key)
  end

  def array_product(ary, *other_arys)
    ary.product(*other_arys)
  end

  # -- apply static filters ---------------------------------------------------

  def apply_static_filters(scope, filters, column_types:)
    return scope if filters.empty?

    filters.inject(scope) do |scp, (k, v)|
      scp.where k => resolve_static_matches(v, column_type: column_types.fetch(k))
    end
  end

  def resolve_static_matches(value, column_type:)
    if value.is_a?(Array)
      return value.map { |v| resolve_static_matches(v, column_type: column_type) }
    end

    case column_type
    when "bigint"   then Integer(value)
    when "integer"  then Integer(value)
    else                 value.to_s
    end
  end

  # -- apply dynamic filters --------------------------------------------------

  def empty_filter?(_key, value)
    return true if value.nil?
    return true if value.is_a?(Enumerable) && value.empty? # i.e. Hash, Array
    false
  end

  def apply_dynamic_filters(scope, filters, dynamic_column:)
    # we translate a condition of "foo => []" into a SQL fragment like this:
    #
    #  NOT (column ? 'foo') OR column @> '{ "foo" : null }'::jsonb)"
    #
    # i.e. we check for non-existing columns and columns that exist but have a
    # value of null (i.e. column->'key' IS NULL).
    empty_filters, filters = filters.partition { |key, value| empty_filter?(key, value) }
    empty_filters.each do |key, _|
      scope = scope.where("(NOT #{dynamic_column} ? '#{key}' OR #{dynamic_column} @> '#{::JSON.generate(key => nil)}'::jsonb)")
    end

    return scope if filters.empty?

    keys = []
    value_arrays = []

    # collect keys and value_arrays for each filter
    filters.each do |key, value|
      keys << key
      # note that resolve_dynamic_matches always returns an array.
      value_arrays << resolve_dynamic_matches(value, key: key)
    end

    # We create a product of all potential value combinations. This is to support
    # search combinations combining multiple values in multiple attributes; like
    # this:
    #
    #     search(foo: %w(bar baz), ids: [1, 2, 3])
    #
    # which is implemented as "(foo='bar' AND ids=1) OR (foo='bar' AND ids=2) ..."
    #
    # I hope we figure out a smart way to use Postgres' JSONB index support to
    # not have to do that.
    #
    # Note: a shorter way to do this would be
    #
    #   "(foo='bar' OR foo='baz') AND (ids=1 OR ids=2 .. )"
    #
    # However, in that case EXPLAIN suggests a more complicated query plan, which
    # suggests that a query might execute faster if there is only a single condition
    # using the JSONB index on each JSONB column.
    product = array_product(*value_arrays)

    # convert each individual combination in the product into a JSONB search
    # condition.
    sql_fragment_parts = product.map do |values|
      match = Hash[keys.zip(values)]
      "#{dynamic_column} @> '#{::JSON.generate(match)}'::jsonb"
    end

    # combine all search conditions with a SQL OR.
    return scope if sql_fragment_parts.empty?

    sql_fragment = "\n\t" + sql_fragment_parts.join(" OR\n\t") + "\n"
    scope.where(sql_fragment)
  end

  # convert value into an array of matches for dynamic attributes. This array
  # might contain integers and strings: We treat each number as a string, and
  # each string which looks like an integer as a number. Consequently searching
  # for "123" in a dynamic attribute would match on 123 *and* on "123".
  def resolve_dynamic_matches(value, key:)
    _ = key

    Array(value).each_with_object([]) do |v, ary|
      ary << v
      ary << Integer(v) if v.is_a?(String) && v =~ /\A-?\d+\z/
      ary << v.to_s unless v.is_a?(String)
    end.uniq
  end
end
