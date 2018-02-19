module Simple
  module SQL
    # Inse
    def insert(table, records)
      if records.is_a?(Hash)
        return insert(table, [records]).first
      end

      return [] if records.empty?

      inserter = Inserter.create(table_name: table.to_s, columns: records.first.keys)
      inserter.insert(records: records)
    end

    class Inserter
      SQL = ::Simple::SQL

      @@inserters = {}

      def self.create(table_name:, columns:)
        @@inserters[[table_name, columns]] ||= new(table_name: table_name, columns: columns)
      end

      #
      # - table_name - the name of the table
      # - columns - name of columns, as Array[String] or Array[Symbol]
      #
      def initialize(table_name:, columns:)
        @columns = columns

        cols = []
        vals = []

        cols += columns
        vals += columns.each_with_index.map { |_, idx| "$#{idx+1}" }

        timestamp_columns = timestamp_columns_in_table(table_name) - columns.map(&:to_s)

        cols += timestamp_columns
        vals += timestamp_columns.map { "now()" }

        @sql = "INSERT INTO #{table_name} (#{cols.join(",")}) VALUES(#{vals.join(",")}) RETURNING id"
      end

      # timestamp_columns are columns that will be set to the current time when
      # inserting a record. This includes:
      #
      # - inserted_at (for Ecto) 
      # - created_at (for ActiveRecord)
      # - updated_at (for Ecto and ActiveRecord)
      def timestamp_columns_in_table(table_name)
        columns_for_table = SQL::Reflection.columns(table_name).keys
        columns_for_table & %w(inserted_at created_at updated_at)
      end

      def insert(records: records)
        SQL.transaction do
          records.map do |record|
            SQL.ask @sql, *record.values_at(*@columns)
          end
        end
      end
    end
  end
end
