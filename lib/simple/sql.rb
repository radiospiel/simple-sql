require "forwardable"
require "logger"
require "expectation"

require_relative "sql/version"
require_relative "sql/helpers"

require_relative "sql/result"
require_relative "sql/config"
require_relative "sql/logging"
require_relative "sql/simple_transactions"
require_relative "sql/scope"
require_relative "sql/connection_adapter"
require_relative "sql/connection"
require_relative "sql/reflection"
require_relative "sql/insert"
require_relative "sql/duplicate"

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

      connection = Connection.pg_connection(database_url)
      self.connector = lambda { connection }
    end

    # disconnects the current connection.
    def disconnect!
      return unless connector

      connection.disconnect!
      self.connector = nil
    end
  end
end
