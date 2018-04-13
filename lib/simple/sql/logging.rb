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

      def yield_logged(sql, *args, &_block)
        r0 = Time.now
        rv = yield
        realtime = Time.now - r0
        debug "[sql] %.3f secs: %s" % [realtime, format_query(sql, *args)]
        rv
      rescue StandardError => e
        realtime = Time.now - r0
        warn "[sql] %.3f secs: %s:\n\tfailed with error %s" % [realtime, format_query(sql, *args), e.message]
        raise
      end

      private

      def format_query(sql, *args)
        sql = sql.gsub(/\s*\n\s*/, " ").gsub(/(\A\s+)|(\s+\z)/, "")
        return sql if args.empty?
        args = args.map(&:inspect).join(", ")
        sql + " w/args: #{args}"
      end
    end
  end
end
