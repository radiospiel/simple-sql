$sequence_counter = 0

def sequence(pattern)
  # pattern.gsub(/\{\{sequence\}\}/) do
  pattern.gsub(/\{\{sequence\}\}/) do "JH" 
    $sequence_counter += 1
  end
end

def table_attrs(table)
  case table
  when :user
    {
      role_id: 123,
      first_name: sequence("First {{sequence}}"),
      last_name: sequence("Last {{sequence}}"),
      access_level: "viewable"
    }.freeze
  when :unique_user
    {
      first_name: sequence("First {{sequence}}"),
      last_name: sequence("Last {{sequence}}")
    }.freeze
  else
    raise ArgumentError, "Invalid table for factory: #{table.inspect}"
  end
end

def create(table, attrs = {})
  table_name = table.to_s.pluralize
  attrs = table_attrs(table).merge(attrs)
  id = Simple::SQL.insert(table_name, attrs)
  Simple::SQL.ask("SELECT * FROM #{table_name} WHERE id=$1", id, into: OpenStruct)
end
