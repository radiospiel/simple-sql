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
        recs = all <<~SQL, schema, into: Hash
          SELECT table_schema || '.' || table_name AS name, *
          FROM information_schema.tables
          WHERE table_schema=$1
        SQL
        records_by_attr(recs, :name)
      end

      def column_info(table_name)
        @column_info ||= {}
        @column_info[table_name] ||= _column_info(table_name)
      end

      private

      def _column_info(table_name)
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

      public

      def lookup_pg_class(oid)
        @pg_classes ||= {}
        @pg_classes[oid] ||= _lookup_pg_class(oid)
      end

      private

      def _lookup_pg_class(oid)
        ::Simple::SQL.ask <<~SQL, oid
          SELECT nspname AS schema, relname AS host_table
          FROM pg_class
          JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
          WHERE pg_class.oid=$1
        SQL
      end
    end
  end
end
