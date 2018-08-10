module Simple
  module SQL
    module Reflection
      extend self

      extend Forwardable
      delegate [:ask, :all, :records, :record] => ::Simple::SQL

      def tables(schema: "public")
        table_info(schema: schema).keys
      end

      def primary_key_columns(table_name)
        all <<~SQL, table_name
          SELECT pg_attribute.attname
          FROM   pg_index
          JOIN   pg_attribute ON pg_attribute.attrelid = pg_index.indrelid AND pg_attribute.attnum = ANY(pg_index.indkey)
          WHERE  pg_index.indrelid = $1::regclass
          AND    pg_index.indisprimary;
        SQL
      end

      TIMESTAMP_COLUMN_NAMES = %w(inserted_at created_at updated_at)

      # timestamp_columns are columns that will be set automatically after
      # inserting or updating a record. This includes:
      #
      # - inserted_at (for Ecto)
      # - created_at (for ActiveRecord)
      # - updated_at (for Ecto and ActiveRecord)
      def timestamp_columns(table_name)
        columns(table_name) & TIMESTAMP_COLUMN_NAMES
      end

      def columns(table_name)
        column_info(table_name).keys
      end

      def table_info(schema: "public")
        columns = if schema == "public"
                    "table_name AS name, *"
                  else
                    "table_schema || '.' || table_name AS name, *"
                  end

        recs = all <<~SQL, schema, into: Hash
          SELECT #{columns}
          FROM information_schema.tables
          WHERE table_schema=$1
          SQL
        records_by_attr(recs, :name)
      end

      def column_info(table_name)
        schema, table_name = parse_table_name(table_name)
        recs = all <<~SQL, schema, table_name, into: Hash
          SELECT
            column_name AS name,
            *
          FROM information_schema.columns
          WHERE table_schema=$1 AND table_name=$2
        SQL

        records_by_attr(recs, :column_name)
      end

      private

      def parse_table_name(table_name)
        p1, p2 = table_name.split(".", 2)
        if p2
          [p1, p2]
        else
          ["public", p1]
        end
      end

      def records_by_attr(records, attr)
        records.inject({}) do |hsh, record|
          record.reject! { |_k, v| v.nil? }
          hsh.update record[attr] => OpenStruct.new(record)
        end
      end
    end
  end
end
