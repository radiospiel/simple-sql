# rubocop:disable Metrics/AbcSize

require_relative "formatting"

module Simple
  module SQL
    module Logging
      extend self

      # The logger object.
      #
      # If no logger was set via <tt>Simple::SQL::Logging.logger = <foo></tt>
      # this returns a default logger.
      def logger
        @logger ||= default_logger
      end

      # The logger object.
      def logger=(logger)
        @logger = logger
      end

      private

      def default_logger
        # return the ActiveRecord logger, if it exists.
        if defined?(ActiveRecord)
          logger = ActiveRecord::Base.logger
          return logger if logger
        end

        # returns a stderr_logger
        @stderr_logger ||= begin
          logger = Logger.new(STDERR)
          logger.level = Logger::INFO
          logger
        end
      end

      public

      extend Forwardable
      delegate [:debug, :info, :warn, :error, :fatal] => :logger

      def slow_query_treshold
        @slow_query_treshold
      end

      def slow_query_treshold=(slow_query_treshold)
        expect! slow_query_treshold > 0
        @slow_query_treshold = slow_query_treshold
      end

      def with_logged_query(sql, *args, &_block)
        r0 = Time.now
        rv = yield
        runtime = Time.now - r0

        logger.debug do
          "[sql] %.3f secs: %s" % [runtime, Formatting.format(sql, *args)]
        end

        if slow_query_treshold && runtime > slow_query_treshold
          log_slow_query(sql, *args, runtime: runtime)
        end

        rv
      rescue StandardError => e
        runtime = Time.now - r0
        logger.warn do
          "[sql] %.3f secs: %s:\n\tfailed with error %s" % [runtime, Formatting.format(sql, *args), e.message]
        end

        raise
      end

      private

      Formatting = ::Simple::SQL::Formatting

      def log_slow_query(sql, *args, runtime:)
        # Do not try to analyze an EXPLAIN query. This prevents endless recursion here
        # (and, in general, would not be useful anyways.)
        return if sql =~ /^EXPLAIN /

        log_multiple_lines ::Logger::WARN, prefix: "[sql-slow]" do
          formatted_query = Formatting.pretty_format(sql, *args)
          query_plan = ::Simple::SQL.all "EXPLAIN ANALYZE #{sql}", *args

          <<~MSG
            === slow query detected: (#{'%.3f secs' % runtime}) ===================================================================================
            #{formatted_query}
            --- query plan: -------------------------------------------------------------------
            #{query_plan.join("\n")}
            ===================================================================================
          MSG
        end
      end

      def log_multiple_lines(level, str = nil, prefix:)
        logger.log(level) do
          str = yield if str.nil?
          str = str.gsub("\n", "\n#{prefix} ") if prefix
          str
        end
      end
    end
  end
end
