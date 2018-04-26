require "forwardable"
require "logger"

require_relative "sql/version.rb"
require_relative "sql/decoder.rb"
require_relative "sql/encoder.rb"
require_relative "sql/config.rb"
require_relative "sql/logging.rb"
require_relative "sql/simple_transactions.rb"
require_relative "sql/scope.rb"
require_relative "sql/connection_adapter.rb"
require_relative "sql/connection.rb"
require_relative "sql/reflection.rb"
require_relative "sql/insert.rb"
require_relative "sql/duplicate.rb"

module Simple
  # The Simple::SQL module
  module SQL
    extend self
    extend Forwardable
    delegate [:ask, :all, :each, :exec] => :connection
    delegate [:transaction, :wait_for_notify] => :connection

    delegate [:logger, :logger=] => ::Simple::SQL::Logging

    private

    def connection
      connector.call
    end

    # The connector attribute returns a lambda, which, when called, returns a connection
    # object.
    #
    # If this seems weird: this is for interacting with ActiveRecord. To be in sync how
    # Rails handles ActiveRecord connections (it checks it out of a connection pool when
    # needed for the first time in a request cycle, and checks it in afterwards) we need
    # to make sure not to keep a reference to the actual connection object around. Instead
    # we need to be able to call a function (in that case ActiveRecord::Base.connection).
    #
    # In non-Rails mode the connector really is a lambda which just returns an object.
    #
    # In any case the connector is stored in a thread-safe fashion. This is not necessary
    # in Rails mode (because AR::B.connection itself is thread-safe already), but in non-
    # Rails-mode we make sure to manage one connection per thread.
    def connector=(connector)
      Thread.current[:"Simple::SQL.connector"] = connector
    end

    def connector
      Thread.current[:"Simple::SQL.connector"] ||= lambda { connect_to_active_record }
    end

    def connect_to_active_record
      return Connection.active_record_connection if defined?(ActiveRecord)

      STDERR.puts <<~SQL
        Simple::SQL works out of the box with ActiveRecord-based postgres connections, reusing the current connection.
        To use without ActiveRecord you must connect to a database via Simple::SQL.connect!.
      SQL

      raise ArgumentError, "simple-sql: missing connection"
    end

    public

    # returns a configuration hash, either from the passed in database URL,
    # from a DATABASE_URL environment value, or from the config/database.yml
    # file.
    def configuration(database_url = :auto)
      database_url = Config.determine_url if database_url == :auto
      Config.parse_url(database_url)
    end

    # connects to the database specified via the url parameter. If called
    # without argument it tries to determine a DATABASE_URL from either the
    # environment setting (DATABASE_URL) or from a config/database.yml file,
    # taking into account the RAILS_ENV and RACK_ENV settings.
    def connect!(database_url = :auto)
      database_url = Config.determine_url if database_url == :auto

      Logging.info "Connecting to #{database_url}"
      config = Config.parse_url(database_url)

      require "pg"
      connection = Connection.pg_connection(PG::Connection.new(config))
      self.connector = lambda { connection }
    end

    # disconnects the current connection.
    def disconnect!
      self.connector = nil
    end
  end
end
