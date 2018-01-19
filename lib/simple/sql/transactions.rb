# private
module Simple::SQL::Transactions
  SELF = self

  def self.nesting_level
    Thread.current[:nesting_level] ||= 0
  end

  def self.nesting_level=(nesting_level)
    Thread.current[:nesting_level] = nesting_level
  end

  def transaction(&block)
    # Notes: by using "ensure" (as opposed to rescue) we are rolling back 
    # both when an exception was raised and when a value was thrown. This 
    # also means we have to track whether or not to rollback. i.e. do roll
    # back when we yielded to &block but not otherwise.
    #
    # Also the transaction support is a bit limited: you cannot rollback.
    # Rolling back from inside a nested transaction would require SAVEPOINT
    # support; without the code is simpler at least :)
    if SELF.nesting_level == 0
      transaction_started = true
      ask "BEGIN"
    end

    SELF.nesting_level += 1

    return_value = yield

    # Only commit if we started a transaction here.
    if transaction_started
      ask "COMMIT"
      transaction_committed = true
    end

    return_value
  ensure
    SELF.nesting_level -= 1
    if transaction_started && !transaction_committed
      ask "ROLLBACK"
    end
  end
end
