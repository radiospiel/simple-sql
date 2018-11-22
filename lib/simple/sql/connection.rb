require "pg"

# private
module Simple::SQL::Connection
  Logging = ::Simple::SQL::Logging

  def self.active_record_connection
    ActiveRecordConnection
  end

  def self.pg_connection(database_url)
    config = ::Simple::SQL::Config.parse_url(database_url)

    Logging.info "Connecting to #{database_url}"

    raw_connection = PG::Connection.new(config)
    raw_connection.set_notice_processor { |message| Logging.info(message) }
    PgConnection.new(raw_connection)
  end

  # A PgConnection object is built around a raw connection. It includes
  # the ConnectionAdapter, which implements ask, all, + friends, and also
  # includes a quiet simplistic Transaction implementation
  class PgConnection
    attr_reader :raw_connection

    def initialize(raw_connection)
      @raw_connection = raw_connection
    end

    def disconnect!
      return unless @raw_connection

      Logging.info "Disconnecting from database"
      @raw_connection.close
      @raw_connection = nil
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
    delegate [:wait_for_notify] => :raw_connection    # wait_for_notify

    def raw_connection
      ActiveRecord::Base.connection.raw_connection
    end

    def disconnect!
      # This doesn't really disconnect. We hope ActiveRecord puts the connection
      # back into the connection pool instead.
      @raw_connection = nil
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
