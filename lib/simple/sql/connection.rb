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
    return ActiveRecordConnection.new if database_url == :auto && defined?(::ActiveRecord)

    database_url = Simple::SQL::Config.determine_url if database_url == :auto

    RawConnection.new database_url
  end

  include Simple::SQL::ConnectionAdapter

  extend Forwardable
  delegate [:wait_for_notify] => :raw_connection
end

require_relative "connection/raw_connection"
require_relative "connection/active_record_connection"
