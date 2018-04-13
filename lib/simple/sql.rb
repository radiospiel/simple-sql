require "forwardable"
require "logger"

require_relative "sql/version.rb"
require_relative "sql/decoder.rb"
require_relative "sql/encoder.rb"
require_relative "sql/config.rb"
require_relative "sql/logging.rb"
require_relative "sql/simple_transactions.rb"
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
    delegate [:ask, :all, :each] => :connection
    delegate [:transaction, :wait_for_notify] => :connection

    def logger
      @logger ||= default_logger
    end

    def logger=(logger)
      @logger = logger
    end

    def default_logger
      logger = ActiveRecord::Base.logger if defined?(ActiveRecord)
      return logger if logger

      logger = Logger.new(STDERR)
      logger.level = Logger::INFO
      logger
    end

    private

    def connection
      @connector.call
    end

    def connector=(connector)
      @connector = connector
    end

    self.connector = lambda {
      connect_to_active_record
    }

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

      logger.info "Connecting to #{database_url}"
      config = Config.parse_url(database_url)

      require "pg"
      connection = Connection.pg_connection(PG::Connection.new(config))
      self.connector = lambda { connection }
    end
  end
end
