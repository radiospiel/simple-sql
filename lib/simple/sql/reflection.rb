module Simple
  module SQL
    module Reflection
      extend self

      extend Forwardable
      delegate [:ask, :all, :records, :record] => ::Simple::SQL

      def tables(schema: "public")
        records = ::Simple::SQL.records <<~SQL, schema
          SELECT
            table_schema || '.' || table_name AS name,
            *
          FROM information_schema.tables
          WHERE table_schema=$1
        SQL

        records_by_attr(records, :name)
      end

      def columns(table_name)
        schema, table_name = parse_table_name(table_name)
        records = ::Simple::SQL.records <<~SQL, schema, table_name
          SELECT
            column_name AS name,
            *
          FROM information_schema.columns
          WHERE table_schema=$1 AND table_name=$2
        SQL

        records_by_attr(records, :column_name)
      end

      private

      def parse_table_name(table_name)
        p1, p2 = table_name.split(".", 2)
        if p2
          [ p1, p2 ]
        else
          [ "public", p1 ]
        end
      end

      def records_by_attr(records, attr)
        records.inject({}) do |hsh, record|
          hsh.update record[attr] => OpenStruct.new(record)
        end
      end
    end
  end
end
