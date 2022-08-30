require "digest/crc32"

class Simple::SQL::Connection
  # Executes a block, usually of db insert code, while holding an
  # advisory lock.
  #
  # This code is deprecated; one should use lock! instead.
  #
  # Examples:
  #
  # - <tt>Simple::SQL.locked(4711) { puts 'do work while locked' }
  def locked(lock_id)
    lock! lock_id
    yield
  end

  # Returns true if we are inside a transaction.
  def in_transaction?
    # This works because each SELECT is run either inside an existing transaction
    # or inside a temporary, for this statement only, transaction which gets
    # deleted after the statement - and which results in different txids.
    txid1 = ask "select txid_current()"
    txid2 = ask "select txid_current()"
    txid1 == txid2
  end

  # Acquire an advisory lock.
  #
  # This uses the pg_*_xact_lock locks - that once acquired, cannot be released,
  # but will release automatically once the transaction ends. This is safer than
  # the pg_advisory_lock group of functions.
  #
  # For ease of use the key argument can also be a string - in which case we use
  # a hash function to derive a key value. Usage example:
  #
  #     Simple::SQL.lock! "products", 12
  #     Simple::SQL.ask "UPDATE products SET ... WHERE id=12"
  #
  # Note that passing in a timeout value sets timeouts for all lock! invocations
  # in this transaction.
  def lock!(key, key2 = nil, timeout: nil)
    unless in_transaction?
      raise "You cannot use lock! outside of a transaction"
    end

    if key.is_a?(String)
      # calculate a 31 bit checksum < 0
      key = Digest::CRC32.hexdigest(key).to_i(16) # get a 32-bit stable checksum
      key &= ~0x80000000 # reset bit 31
      key = -key # make it negative
    end

    # shorten key, key2 to the allowed number of bits
    if key2
      key  = apply_bitmask(key, MASK_31_BITS)
      key2 = apply_bitmask(key2, MASK_31_BITS)
    else
      key = apply_bitmask(key, MASK_63_BITS)
    end

    if timeout
      lock_w_timeout(key, key2, timeout)
    else
      lock_wo_timeout(key, key2)
    end
  end

  private

  MASK_31_BITS = 0x7fffffff
  MASK_63_BITS = 0x7fffffffffffffff

  def apply_bitmask(n, mask)
    if n < 0
      -((-n) & mask)
    else
      n & mask
    end
  end

  def lock_wo_timeout(key, key2)
    ask("SET LOCAL lock_timeout TO DEFAULT")

    if key2
      ask("SELECT pg_advisory_xact_lock($1, $2)", key, key2)
    else
      ask("SELECT pg_advisory_xact_lock($1)", key)
    end
  end

  # rubocop:disable Style/IfInsideElse
  def lock_w_timeout(key, key2, timeout)
    expect! timeout => 0..3600

    timeout_string = "%dms" % (timeout * 1000)
    ask("SET LOCAL lock_timeout = '#{timeout_string}'")

    if key2
      return if ask("SELECT pg_try_advisory_xact_lock($1, $2)", key, key2)
    else
      return if ask("SELECT pg_try_advisory_xact_lock($1)", key)
    end

    raise "Cannot get lock w/key #{key.inspect} and key2 #{key2.inspect} within #{timeout} seconds"
  end
end
