class Simple::SQL::Connection
end

require "pg"

# pg 0.21 prints deprecation warnings when using its definitions of PGconn,
# PGError, and PGResult. The below blocks circumvents this - and we are doing this
unless defined?(PGconn)
  PGconn = PG::Connection
  PGError = PG::Error
  PGResult = PG::Result
end

require "active_record"

require_relative "connection/base"
require_relative "connection/lock"
require_relative "connection/scope"
require_relative "connection/reflection"
require_relative "connection/insert"
require_relative "connection/duplicate"
require_relative "connection/type_info"

# A Connection object. This wraps an ActiveRecord::Base connection.
#
# It Method.includes the ConnectionAdapter, which implements ask, all, + friends
#
class Simple::SQL::Connection
  def self.create(database_url = :auto)
    case database_url
    when nil    then DefaultConnection.new
    when String then ExplicitConnection.new(database_url)
    when :auto
      if ::ActiveRecord::Base.connected?
        DefaultConnection.new
      else
        ExplicitConnection.new(::Simple::SQL::Config.determine_url)
      end
    else
      expect! database_url => [nil, :auto, String]
    end
  end

  def initialize(active_record_class)
    @active_record_class = active_record_class
  end

  def raw_connection
    @active_record_class.connection.raw_connection
  end

  def transaction(&block)
    @active_record_class.connection.transaction(&block)
  end

  extend Forwardable
  delegate [:wait_for_notify] => :raw_connection

  # -- specific connection classes --------------------------------------------

  class DefaultConnection < self
    def initialize
      @active_record_class = ::ActiveRecord::Base
    end

    def disconnect!; end
  end

  class ExplicitConnection < self
    def initialize(url)
      super create_active_record_class(url)
    end

    def disconnect!
      return unless @active_record_class

      @active_record_class.remove_connection
    end

    private

    # ActiveRecord needs a class name in order to connect.
    module WritableClassName
      attr_accessor :name
    end

    # create_active_record_class builds a ActiveRecord::Base class, whose
    # ConnectionPool we are going to use for this connection.
    def create_active_record_class(url)
      Class.new(ActiveRecord::Base).tap do |klass|
        klass.extend WritableClassName
        klass.name = "Simple::SQL::Connection::ExplicitConnection::Adapter"
        klass.establish_connection url

        connection_pool = klass.connection_pool
        connection_pool_stats = {
          size: connection_pool.size,
          automatic_reconnect: connection_pool.automatic_reconnect,
          checkout_timeout: connection_pool.checkout_timeout
        }
        ::Simple::SQL.logger.info "#{url}: connected to connection pool w/#{connection_pool_stats.inspect}"
      end
    end
  end
end
