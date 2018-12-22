module Simple
  module SQL
    module Formatting
      extend self

      def format(sql, *args)
        sql = format_sql(sql)

        return sql if args.empty?

        args = args.map(&:inspect).join(", ")
        sql += " w/args: #{args}"
        sql = sql[0, 98] + "..." if sql.length > 100
        sql
      end

      def pretty_format(sql, *args)
        sql = if use_pg_format?
                pg_format_sql(sql)
              else
                format_sql(sql)
              end

        args = args.map(&:inspect).join(", ")
        "#{sql} w/args: #{args}"
      end

      private

      def format_sql(sql)
        sql.gsub(/\s*\n\s*/, " ").gsub(/(\A\s+)|(\s+\z)/, "")
      end

      require "open3"

      def use_pg_format?
        return @use_pg_format unless @use_pg_format.nil?

        `which pg_format`
        if $?.exitstatus == 0
          @use_pg_format = true
        else
          Simple::SQL.logger.warn "[sql] simple-sql can use pg_format for logging queries. Please see https://github.com/darold/pgFormatter"
          @use_pg_format = false
        end
      end

      PG_FORMAT_ARGS = "--function-case 2 --maxlength 15000 --nocomment --spaces 2 --keyword-case 2 --no-comma-end"

      def pg_format_sql(sql)
        stdin, stdout, _ = Open3.popen2("pg_format #{PG_FORMAT_ARGS} -")
        stdin.print sql
        stdin.close
        formatted = stdout.read
        stdout.close
        formatted
      end
    end
  end
end
