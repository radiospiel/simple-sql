# This file contains some monkey patches

# rubocop:disable Lint/DuplicateMethods

module Simple::SQL::MonkeyPatches
  def self.warn(msg)
    return if ENV["SIMPLE_SQL_SILENCE"] == "1"

    @@warned ||= {}
    return if @@warned[msg]

    @@warned[msg] = true

    STDERR.puts "== monkeypatch warning: #{msg} (set SIMPLE_SQL_SILENCE=1 to disable)"
  end
end

case ActiveRecord.gem_version.to_s
when /^4/
  :nop
when /^5.2/
  unless defined?(ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper)
    raise "Make sure to properly require active-record first"
  end

  # Rails5 introduced a Reaper which starts a Thread which checks for unused connections. However,
  # these threads are never cleaned up. This monkey patch disables the creation of those threads
  # in the first place, consequently preventing leakage of threads.
  #
  # see see https://github.com/rails/rails/issues/33600 and related commits and issues.
  class ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper
    def run
      return unless frequency && frequency > 0

      Simple::SQL::MonkeyPatches.warn "simple-sql disables reapers for all connection pools, see https://github.com/rails/rails/issues/33600"
    end
  end

when /^6/
  unless defined?(ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper)
    raise "Make sure to properly require active-record first"
  end

  # Rails6 fixes the issue w/reapers leaking threads; by properly cleaning up these threads
  # (or  so one hopes after looking at connection_pool.rb). However, in the interest of simple-sql
  # being more or less ActiveRecord agnostic we disable reaping here as well. (Also, that code
  # looks pretty complex to me).
  class ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper
    def run
      return unless frequency && frequency > 0

      Simple::SQL::MonkeyPatches.warn "simple-sql disables reapers for all connection pools, see https://github.com/rails/rails/issues/33600"
    end
  end
end
