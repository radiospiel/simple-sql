# private
module Simple::SQL::Connection
  def self.new(connection)
    if defined?(ActiveRecord)
      if connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        return ActiveRecordConnection.new(connection)
      end
    end

    SimpleConnection.new(connection)
  end

  class RawConnection
    def initialize(raw_connection)
      @raw_connection = raw_connection
    end

    extend Forwardable
    delegate %w(exec_params exec escape wait_for_notify) => :@raw_connection

    def transaction(&block)
      raise ArgumentError, "Implementation missing for #transaction"
    end
  end

  class SimpleConnection < RawConnection
    def initialize(raw_connection)
      super(raw_connection)
      @tx_nesting_level = 0
    end

    private

    def transaction(&block)
      # Notes: by using "ensure" (as opposed to rescue) we are rolling back 
      # both when an exception was raised and when a value was thrown. This 
      # also means we have to track whether or not to rollback. i.e. do roll
      # back when we yielded to &block but not otherwise.
      #
      # Also the transaction support is a bit limited: you cannot rollback.
      # Rolling back from inside a nested transaction would require SAVEPOINT
      # support; without the code is simpler at least :)

      if @tx_nesting_level == 0
        exec "BEGIN"
        tx_started = true
      end

      @tx_nesting_level += 1

      return_value = yield

      # Only commit if we started a transaction here.
      if tx_started
        exec "COMMIT"
        tx_committed = true
      end

      return_value
    ensure
      @tx_nesting_level -= 1
      if tx_started && !tx_committed
        exec "ROLLBACK"
      end
    end
  end

  class ActiveRecordConnection < RawConnection
    def initialize(connection)
      super(connection.raw_connection)
      @connection = connection
    end

    delegate :transaction => :@connection
  end
end
