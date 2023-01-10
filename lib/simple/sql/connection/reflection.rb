# rubocop:disable Metrics/ClassLength

class Simple::SQL::Connection
  def reset_reflection
    @reflection = nil
  end

  def reflection
    @reflection ||= Reflection.new(self)
  end

  class Reflection
    def initialize(connection)
      @connection = connection
    end

    def tables(schema: "public")
      table_info(schema: schema).keys
    end

    def primary_key_column(table_name)
      @primary_key_column ||= {}
      @primary_key_column[table_name] ||= begin
        pk_column, other = primary_key_columns(table_name)

        raise "#{table_name}: No support for combined primary keys" if other
        raise "#{table_name}: No primary key" if pk_column.nil?

        pk_column
      end
    end

    def primary_key_columns(table_name)
      @primary_key_columns ||= {}
      @primary_key_columns[table_name] ||= _primary_key_columns(table_name)
    end

    private

    def _primary_key_columns(table_name)
      sql = <<~SQL
        SELECT pg_attribute.attname
        FROM   pg_index
        JOIN   pg_attribute ON pg_attribute.attrelid = pg_index.indrelid AND pg_attribute.attnum = ANY(pg_index.indkey)
        WHERE  pg_index.indrelid = $1::regclass
        AND    pg_index.indisprimary;
      SQL

      @connection.all(sql, table_name)
    end

    public

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

    def column_info(table_name)
      @column_info ||= {}
      @column_info[table_name] ||= _column_info(table_name)
    end

    # returns a Hash of column_name => column_type. Names are available both as
    # Symbol and as String.
    def column_types(table_name)
      @column_types ||= {}
      @column_types[table_name] ||= _column_types(table_name)
    end

    def table_info(schema: "public")
      recs = @connection.all <<~SQL, schema, into: Hash
        SELECT table_schema || '.' || table_name AS name, *
        FROM information_schema.tables
        WHERE table_schema=$1
      SQL
      records_by_attr(recs, :name)
    end

    private

    def _column_info(table_name)
      schema, table_name = parse_table_name(table_name)
      recs = @connection.all <<~SQL, schema, table_name, into: Hash
        SELECT
          column_name AS name,
          *
        FROM information_schema.columns
        WHERE table_schema=$1 AND table_name=$2
      SQL

      records_by_attr(recs, :column_name)
    end

    def _column_types(table_name)
      column_info = column_info(table_name)
      column_info.each_with_object({}) do |(column_name, rec), hsh|
        hsh[column_name.to_sym] = hsh[column_name.to_s] = rec.data_type
      end
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
        record.compact!
        hsh.update record[attr] => OpenStruct.new(record)
      end
    end

    public

    def looked_up_pg_classes
      @looked_up_pg_classes ||= Hash.new { |hsh, key| hsh[key] = _lookup_pg_class(key) }
    end

    def lookup_pg_class(oid)
      looked_up_pg_classes[oid]
    end

    private

    def _lookup_pg_class(oid)
      @connection.ask <<~SQL, oid
        SELECT nspname AS schema, relname AS host_table
        FROM pg_class
        JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
        WHERE pg_class.oid=$1
      SQL
    end
  end
end
