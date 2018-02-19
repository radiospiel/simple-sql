# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/LineLength

module Simple
  module SQL
    module Logging
      extend self

      def yield_logged(sql, *args, &_block)
        r0 = Time.now
        rv = yield
        realtime = Time.now - r0
        ::Simple::SQL.logger.debug "[sql] %.3f secs: %s" % [realtime, format_query(sql, *args)]
        rv
      rescue StandardError => e
        realtime = Time.now - r0
        ::Simple::SQL.logger.warn "[sql] %.3f secs: %s:\n\tfailed with error %s" % [realtime, format_query(sql, *args), e.message]
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
