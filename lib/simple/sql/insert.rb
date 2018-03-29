# rubocop:disable Style/ClassVars
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/LineLength
module Simple
  module SQL
    #
    # - table_name - the name of the table
    # - records - a single hash of attributes or an array of hashes of attributes
    # - handle_conflict - uses a postgres ON CONFLICT clause to ignore insert conflicts if true
    #
    def insert(table, records, handle_conflict: false)
      if records.is_a?(Hash)
        insert_many(table, [records], handle_conflict).first
      else
        insert_many(table, records, handle_conflict)
      end
    end

    private

    def insert_many(table, records, handle_conflict)
      return [] if records.empty?

      inserter = Inserter.create(table_name: table.to_s, columns: records.first.keys, handle_conflict: handle_conflict)
      inserter.insert(records: records)
    end

    class Inserter
      SQL = ::Simple::SQL

      @@inserters = {}

      def self.create(table_name:, columns:, handle_conflict:)
        @@inserters[[table_name, columns, handle_conflict]] ||= new(table_name: table_name, columns: columns, handle_conflict: handle_conflict)
      end

      #
      # - table_name - the name of the table
      # - columns - name of columns, as Array[String] or Array[Symbol]
      #
      def initialize(table_name:, columns:, handle_conflict:)
        @columns = columns

        cols = []
        vals = []

        cols += columns
        vals += columns.each_with_index.map { |_, idx| "$#{idx + 1}" }

        timestamp_columns = SQL::Reflection.timestamp_columns(table_name) - columns.map(&:to_s)

        cols += timestamp_columns
        vals += timestamp_columns.map { "now()" }

        confict_handling = handle_conflict ? " ON CONFLICT DO NOTHING " : ""

        @sql = "INSERT INTO #{table_name} (#{cols.join(',')}) VALUES(#{vals.join(',')}) #{confict_handling} RETURNING id"
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
