# rubocop:disable Style/ClassVars
# rubocop:disable Metrics/AbcSize

module Simple
  module SQL
    def insert(table, records)
      if records.is_a?(Hash)
        insert_many(table, [records]).first
      else
        insert_many table, records
      end
    end

    private

    def insert_many(table, records)
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
        vals += columns.each_with_index.map { |_, idx| "$#{idx + 1}" }

        timestamp_columns = SQL::Reflection.timestamp_columns(table_name) - columns.map(&:to_s)

        cols += timestamp_columns
        vals += timestamp_columns.map { "now()" }

        @sql = "INSERT INTO #{table_name} (#{cols.join(',')}) VALUES(#{vals.join(',')}) RETURNING id"
      end

      def insert(records:)
        SQL.transaction do
          records.map do |record|
            SQL.ask @sql, *record.values_at(*@columns)
          end
        end
      end
    end
  end
end
