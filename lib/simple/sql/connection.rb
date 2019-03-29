# A Connection object.
#
# A Connection object is built around a raw connection (as created from the pg
# ruby gem).
#
#
# It includes
# the ConnectionAdapter, which implements ask, all, + friends, and also
# includes a quiet simplistic Transaction implementation
class Simple::SQL::Connection
  def self.create(database_url = :auto)
    case database_url
    when :auto
      if defined?(::ActiveRecord)
        ActiveRecordConnection.new
      else
        RawConnection.new Simple::SQL::Config.determine_url
      end
    else
      RawConnection.new database_url
    end
  end

  include Simple::SQL::ConnectionAdapter

  def reflection
    @reflection ||= ::Simple::SQL::Reflection.new(self)
  end

  #
  # Creates duplicates of record in a table.
  #
  # This method handles timestamp columns (these will be set to the current
  # time) and primary keys (will be set to NULL.) You can pass in overrides
  # as a third argument for specific columns.
  #
  # Parameters:
  #
  # - ids: (Integer, Array<Integer>) primary key ids
  # - overrides: Hash[column_names => SQL::Fragment]
  #
  def duplicate(table, ids, overrides = {})
    ids = Array(ids)
    return [] if ids.empty?

    ::Simple::SQL::Duplicator.new(self, table, overrides).call(ids)
  end

  #
  # - table_name - the name of the table
  # - records - a single hash of attributes or an array of hashes of attributes
  # - on_conflict - uses a postgres ON CONFLICT clause to ignore insert conflicts if true
  #
  def insert(table, records, on_conflict: nil, into: nil)
    if records.is_a?(Hash)
      inserted_records = insert(table, [records], on_conflict: on_conflict, into: into)
      return inserted_records.first
    end

    return [] if records.empty?

    table_name = table.to_s
    columns = records.first.keys

    @inserters ||= {}
    inserter = @inserters[[table_name, columns, on_conflict, into]] ||= ::Simple::SQL::Inserter.new(self, table_name: table_name, columns: columns, on_conflict: on_conflict, into: into)
    inserter.insert(records: records)
  end

  extend Forwardable
  delegate [:wait_for_notify] => :raw_connection
end

require_relative "connection/raw_connection"
require_relative "connection/active_record_connection"
