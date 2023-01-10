# rubocop:disable Lint/EmptyClass
class Simple::SQL::Connection
end
# rubocop:enable Lint/EmptyClass

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
    return ::ActiveRecord::Base if database_url.nil?
    return ConnectionManager.connection_class(database_url) if database_url.is_a?(String)

    # database_url is :auto, and we are connected. This happens, for example,
    # within a rails controller. IT IS IMPORTANT NOT TO CONNECT AGAINST THE
    # ::Simple::SQL::Config.determine_url! Only so we can make sure that
    # simple-sql and ActiveRecord can be mixed freely together, i.e. they are
    # sharing the same connection.
    return ::ActiveRecord::Base if ::ActiveRecord::Base.connected?

    ConnectionManager.connection_class(::Simple::SQL::Config.determine_url)
  end

  def initialize(connection_class)
    @connection_class = connection_class
  end

  def raw_connection
    @connection_class.connection.raw_connection
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
