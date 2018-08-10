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

  # Preloads an association.
  #
  # This can now be used as follows:
  #
  #     scope = SQL::Scope.new("SELECT * FROM users")
  #     results = SQL.all scope, into: :struct
  #     results.preload(:organization)
  #
  # The preload method uses foreign key definitions in the database to figure out
  # which table to load from.
  #
  # This method is only available if <tt>into:</tt> was set in the call to <tt>SQL.all</tt>.
  # It raises an error otherwise.
  #
  # Parameters:
  #
  # - association: the name of the association.
  # - as: the target name of the association.
  #
  # <b>Notes:</b> The actual implementation of this method can be found in
  # ::Simple::SQL::Result::Records#preload.
  def preload(association, as: nil)
    expect! association => Symbol

    raise "preload is not implemented in #{self.class.name}"
  end
end
