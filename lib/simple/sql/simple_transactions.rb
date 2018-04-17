# rubocop:disable Metrics/MethodLength
# rubocop:disable Style/IfUnlessModifier

# private
module Simple::SQL::SimpleTransactions
  def tx_nesting_level
    @tx_nesting_level ||= 0
  end

  def tx_nesting_level=(tx_nesting_level)
    @tx_nesting_level = tx_nesting_level
  end

  def transaction(&_block)
    # Notes: by using "ensure" (as opposed to rescue) we are rolling back
    # both when an exception was raised and when a value was thrown. This
    # also means we have to track whether or not to rollback. i.e. do roll
    # back when we yielded to &block but not otherwise.
    #
    # Also the transaction support is a bit limited: you cannot rollback.
    # Rolling back from inside a nested transaction would require SAVEPOINT
    # support; without the code is simpler at least :)

    if tx_nesting_level == 0
      exec "BEGIN"
      tx_started = true
    end

    self.tx_nesting_level += 1

    return_value = yield

    # Only commit if we started a transaction here.
    if tx_started
      exec "COMMIT"
      tx_committed = true
    end

    return_value
  ensure
    self.tx_nesting_level -= 1
    if tx_started && !tx_committed
      exec "ROLLBACK"
    end
  end
end
