class Simple::SQL::Connection::ActiveRecordConnection < Simple::SQL::Connection
  def initialize
    ::ActiveRecord::Base.connection
  end

  def raw_connection
    ::ActiveRecord::Base.connection.raw_connection
  end

  def transaction(&block)
    ::ActiveRecord::Base.connection.transaction(&block)
  end
end
