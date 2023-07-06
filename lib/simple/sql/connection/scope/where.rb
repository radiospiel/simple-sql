# rubocop:disable Style/GuardClause

class Simple::SQL::Connection::Scope
  # scope = Scope.new("SELECT * FROM tablename")
  # scope = scope.where(id: 12)
  # scope = scope.where("id > ?", 12)
  #
  # In the second form the placeholder (usually a '?') is being replaced
  # with the numbered argument (since postgres is using $1, $2, etc.)
  # If your SQL fragment uses '?' as part of some fixed text you must
  # use an alternative placeholder symbol:
  #
  # scope = scope.where("foo | '?' = '^'", match, placeholder: '^')
  #
  # If a hash is passed in as a search condition and the value to match is
  # a hash, this is translated into a JSONB query, which matches each of
  # the passed in keys against one of the passed in values.
  #
  # scope = scope.where(metadata: { uid: 1, type: ["foo", "bar", "baz"] })
  #
  # This feature can be disabled using the `jsonb: false` option.
  #
  # scope = scope.where(metadata: { uid: 1 }, jsonb: false)
  #
  def where(sql_fragment, arg = :__dummy__no__arg, placeholder: "?", jsonb: true)
    duplicate.where!(sql_fragment, arg, placeholder: placeholder, jsonb: jsonb)
  end

  def where!(first_arg, arg = :__dummy__no__arg, placeholder: "?", jsonb: true)
    if arg != :__dummy__no__arg
      where_sql_with_argument!(first_arg, arg, placeholder: placeholder)
    elsif first_arg.is_a?(Hash)
      where_hash!(first_arg, jsonb: jsonb)
    else
      where_sql!(first_arg)
    end

    self
  end

  private

  def where_sql!(sql_fragment)
    @where << sql_fragment
  end

  def where_sql_with_argument!(sql_fragment, arg, placeholder:)
    @args << arg
    @where << sql_fragment.gsub(placeholder, "$#{@args.length}")
  end

  def where_hash!(hsh, jsonb:)
    hsh.each do |column, value|
      validate_column! column
      if value.is_a?(Hash) && jsonb
        where_jsonb_condition!(column, value)
      else
        where_plain_condition!(column, value)
      end
    end
  end

  ID_REGEXP = /\A[A-Za-z0-9_\.]+\z/

  def validate_column!(column)
    unless column.is_a?(Symbol) || column.is_a?(String)
      raise ArgumentError, "condition key #{column.inspect} must be a Symbol or a String"
    end
    unless column.to_sym =~ ID_REGEXP
      raise ArgumentError, "condition key #{column.inspect} must match #{ID_REGEXP}"
    end
  end

  def jsonb_condition(column, key, value)
    if !value.is_a?(Array)
      "#{column} @> '#{::JSON.generate(key => value)}'"
    elsif value.empty?
      "FALSE"
    else
      individual_conditions = value.map do |v|
        jsonb_condition(column, key, v)
      end
      "(#{individual_conditions.join(' OR ')})"
    end
  end

  def where_jsonb_condition!(column, hsh)
    hsh.each do |key, value|
      @where << jsonb_condition(column, key, value)
    end
  end

  def where_plain_condition!(key, value)
    @args << value

    case value
    when Array
      @where << "#{key} = ANY($#{@args.length})"
    else
      @where << "#{key} = $#{@args.length}"
    end
  end

  def apply_where(sql)
    where = @where.compact
    return sql if where.empty?

    "#{sql} WHERE (" + where.join(") AND (") + ")"
  end
end
