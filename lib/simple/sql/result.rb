require_relative "helpers"

class ::Simple::SQL::Result < Array
end

require_relative "result/rows"
require_relative "result/records"

# The result of SQL.all
#
# This class implements the interface of a Result.
class ::Simple::SQL::Result < Array
  # A Result object is requested via ::Simple::SQL::Result.build, which then
  # chooses the correct implementation, based on the <tt>target_type:</tt>
  # parameter.
  def self.build(records, target_type:, pg_source_oid:) # :nodoc:
    if target_type.nil?
      Rows.new(records)
    else
      Records.new(records, target_type: target_type, pg_source_oid: pg_source_oid)
    end
  end

  attr_reader :total_count
  attr_reader :total_pages
  attr_reader :current_page
end
