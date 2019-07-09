# The ConnectionManager manages a pool of ActiveRecord::Base classes.
#
# ActiveRecord assigns a connection_pool to a class. If you want to connect to
# multiple detabases you must inherit from ActiveRecord::Base. This is what
# we do dynamically in this ConnectionManager.
#
# Note that connections to the same database are always shared within a single
# ConnectionPool.
module Simple::SQL
  module ConnectionManager
    extend self

    def disconnect_all!
      ActiveRecord::Base.connection_pool.disconnect!
      connection_classes.values.map(&:connection_pool).each(&:disconnect!)
      connection_classes.clear
    end

    def connection_class(url)
      connection_classes[url] ||= create_connection_class(url)
    end

    private

    def connection_classes
      @connection_classes ||= {}
    end

    # ActiveRecord needs a class name in order to connect.
    module WritableClassName
      attr_accessor :name
    end

    def create_connection_class(url)
      Class.new(ActiveRecord::Base).tap do |klass|
        klass.extend WritableClassName
        klass.name = "Simple::SQL::Connection::ExplicitConnection::Adapter/#{url}"

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
