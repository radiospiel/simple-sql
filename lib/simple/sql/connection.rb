# private
module Simple::SQL::Connection
  def self.active_record_connection
    ActiveRecordConnection
  end

  def self.pg_connection(connection)
    PgConnection.new(connection)
  end

  # A PgConnection object is built around a raw connection. It includes
  # the ConnectionAdapter, which implements ask, all, + friends, and also
  # includes a quiet simplistic Transaction implementation
  class PgConnection
    attr_reader :raw_connection

    def initialize(raw_connection)
      @raw_connection = raw_connection
    end

    include ::Simple::SQL::ConnectionAdapter          # all, ask, first, etc.
    include ::Simple::SQL::SimpleTransactions         # transactions

    extend Forwardable
    delegate [:wait_for_notify] => :raw_connection    # wait_for_notify
  end

  module ActiveRecordConnection
    extend self

    extend ::Simple::SQL::ConnectionAdapter           # all, ask, first, etc.

    extend Forwardable
    delegate [:transaction] => :connection            # transactions
    delegate [:wait_for_notify] => :connection        # wait_for_notify

    def raw_connection
      ActiveRecord::Base.connection.raw_connection
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
