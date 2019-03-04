require "pg"

class Simple::SQL::Connection::RawConnection < Simple::SQL::Connection
  SELF = self

  attr_reader :raw_connection

  def initialize(database_url)
    @database_url = database_url
    @raw_connection = PG::Connection.new(@database_url)
    ObjectSpace.define_finalizer(self, SELF.finalizer(@raw_connection))
  end

  def self.finalizer(raw_connection)
    proc do
      raw_connection.finish unless raw_connection.finished?
    end
  end

  def disconnect!
    return unless @raw_connection

    @raw_connection.finish unless @raw_connection.finished?
    @raw_connection = nil
  end

  def transaction(&_block)
    @tx_nesting_level ||= 0

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
