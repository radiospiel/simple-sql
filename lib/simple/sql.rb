require_relative "sql/version.rb"
require_relative "sql/decoder.rb"
require_relative "sql/encoder.rb"
require_relative "sql/config.rb"
require_relative "sql/logging.rb"
require_relative "sql/connection.rb"

require "logger"

module Simple
  # The Simple::SQL module
  module SQL
    extend self

    attr_accessor :logger
    self.logger = Logger.new(STDERR)

    # execute one or more sql statements. This method does not allow to pass in
    # arguments - since the pg client does not support this - but it allows to
    # run multiple sql statements separated by ";"
    def exec(sql)
      Logging.yield_logged sql do
        connection.exec sql
      end
    end

    # Runs a query, with optional arguments, and returns the result. If the SQL
    # query returns rows with one column, this method returns an array of these
    # values. Otherwise it returns an array of arrays.
    #
    # Example:
    #
    # - <tt>Simple::SQL.all("SELECT id FROM users")</tt> returns an array of id values
    # - <tt>Simple::SQL.all("SELECT id, email FROM users")</tt> returns an array of
    #         arrays `[ <id>, <email> ]`.
    #
    # Simple::SQL.all "SELECT id, email FROM users" do |id, email|
    #   # do something
    # end

    def all(sql, *args, &block)
      result  = exec_logged(sql, *args)
      decoder = Decoder.new(result)

      enumerate(result, decoder, block)
    end

    # Runs a query and returns the first result row of a query.
    #
    # Examples:
    #
    # - <tt>Simple::SQL.ask "SELECT id FROM users WHERE email=$?", "foo@local"</tt>
    #   returns a number (or +nil+)
    # - <tt>Simple::SQL.ask "SELECT id, email FROM users WHERE email=$?", "foo@local"</tt>
    #   returns an array <tt>[ <id>, <email> ]</tt> (or +nil+)
    def ask(sql, *args)
      catch(:ok) do
        all(sql, *args) { |row| throw :ok, row }
        nil
      end
    end

    # Runs a query, with optional arguments, and returns the result as an
    # array of Hashes.
    #
    # Example:
    #
    # - <tt>Simple::SQL.records("SELECT id, email FROM users")</tt> returns an array of
    #         hashes { id: id, email: email }
    #
    # Simple::SQL.records "SELECT id, email FROM users" do |record|
    #   # do something
    # end

    def records(sql, *args, into: Hash, &block)
      result  = exec_logged(sql, *args)
      decoder = Decoder.new(result, :record, into: into)

      enumerate(result, decoder, block)
    end

    # Runs a query and returns the first result row of a query as a Hash.
    def record(sql, *args, into: Hash)
      catch(:ok) do
        records(sql, *args, into: into) { |row| throw :ok, row }
        nil
      end
    end

    extend Forwardable
    delegate [:transaction, :wait_for_notify] => :connection

    private

    def exec_logged(sql, *args)
      Logging.yield_logged sql, *args do
        connection.exec_params(sql, Encoder.encode_args(args))
      end
    end

    def enumerate(result, decoder, block)
      if block
        result.each_row do |row|
          block.call decoder.decode(row)
        end
        self
      else
        ary = []
        result.each_row { |row| ary << decoder.decode(row) }
        ary
      end
    end

    def resolve_type(ftype, fmod)
      @resolved_types ||= {}
      @resolved_types[[ftype, fmod]] ||= connection.exec("SELECT format_type($1,$2)", [ftype, fmod]).getvalue(0, 0)
    end

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
      return Connection.new(ActiveRecord::Base.connection) if defined?(ActiveRecord)

      STDERR.puts <<-SQL
Simple::SQL works out of the box with ActiveRecord-based postgres connections, reusing the current connection.
To use without ActiveRecord you must connect to a database via Simple::SQL.connect!.
SQL

      raise ArgumentError, "simple-sql: missing connection"
    end

    public

    # connects to the database specified via the url parameter. If called
    # without argument it tries to determine a DATABASE_URL from either the
    # environment setting (DATABASE_URL) or from a config/database.yml file,
    # taking into account the RAILS_ENV and RACK_ENV settings.
    def connect!(database_url = :auto)
      database_url = Config.determine_url if database_url == :auto

      logger.info "Connecting to #{database_url}"
      config = Config.parse_url(database_url)

      require "pg"
      connection = Connection.new(PG::Connection.new(config))
      self.connector = lambda { connection }
    end
  end
end
