module Simple
  module SQL
    module Formatting
      extend self

      MAX_LENGTH = 500

      def format(sql, *args)
        sql = format_sql(sql)

        return sql if args.empty?

        args = args.map(&:inspect).join(", ")
        sql += " w/args: #{args}"
        sql = sql[0, (MAX_LENGTH - 3)] + "..." if sql.length > MAX_LENGTH
        sql
      end

      private

      def format_sql(sql)
        sql.gsub(/\s*\n\s*/, " ").gsub(/(\A\s+)|(\s+\z)/, "")
      end
    end
  end
end
