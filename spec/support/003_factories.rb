$sequence_counter = 0

def sequence(pattern)
  # pattern.gsub(/\{\{sequence\}\}/) do
  pattern.gsub(/\{\{sequence\}\}/) do "JH" 
    $sequence_counter += 1
  end
end

def attrs(table)
  case table
  when :user
    {
      role_id: 123,
      first_name: sequence("First {{sequence}}"),
      last_name: sequence("Last {{sequence}}"),
      access_level: "viewable"
    }
  when :unique_user
    {
      first_name: sequence("First {{sequence}}"),
      last_name: sequence("Last {{sequence}}")
    }
  else
    raise ArgumentError, "Invalid table for factory: #{table.inspect}"
  end
end

def create(table)
  table_name = table.to_s.pluralize
  id = Simple::SQL.insert(table_name, attrs(table))
  Simple::SQL.record("SELECT * FROM #{table_name} WHERE id=$1", id, into: OpenStruct)
end
