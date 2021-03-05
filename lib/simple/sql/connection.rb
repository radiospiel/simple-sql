class Simple::SQL::Connection
end

require "pg"
require "active_record"

require_relative "connection_manager"

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
  ConnectionManager = ::Simple::SQL::ConnectionManager

  def self.create(database_url = :auto)
    expect! database_url => [nil, :auto, String]
    new connection_class(database_url)
  end

  def self.connection_class(database_url)
    # database_url = ::Simple::SQL::Config.determine_url unless database_url.is_a?(String)
    # ConnectionManager.connection_class(database_url)

    if database_url.nil?
      ::ActiveRecord::Base
    elsif database_url.is_a?(String)
      ConnectionManager.connection_class(database_url)
    elsif ::ActiveRecord::Base.connected?
      # database_url is :auto, and we are connected. This happens, for example,
      # within a rails controller. IT IS IMPORTANT NOT TO CONNECT AGAINST THE
      # ::Simple::SQL::Config.determine_url! Only so we can make sure that
      # simple-sql and ActiveRecord can be mixed freely together, i.e. they are
      # sharing the same connection.
      ::ActiveRecord::Base
    else
      ConnectionManager.connection_class(::Simple::SQL::Config.determine_url)
    end
  end

  def initialize(connection_class)
    @connection_class = connection_class
  end

  def raw_connection
    conn = @connection_class.connection.raw_connection
    conn
  end

  def transaction(&block)
    @connection_class.connection.transaction(&block)
  end

  def disconnect!
    return unless @connection_class && @connection_class != ::ActiveRecord::Base
    @connection_class.remove_connection
  end

  extend Forwardable
  delegate [:wait_for_notify] => :raw_connection
end
