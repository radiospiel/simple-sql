# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/LineLength
module Simple
  module SQL
    #
    # - table_name - the name of the table
    # - records - a single hash of attributes or an array of hashes of attributes
    # - on_conflict - uses a postgres ON CONFLICT clause to ignore insert conflicts if true
    #
    def insert(table, records, on_conflict: nil, into: nil)
      if records.is_a?(Hash)
        insert_many(table, [records], on_conflict, into).first
      else
        insert_many(table, records, on_conflict, into)
      end
    end

    private

    def insert_many(table, records, on_conflict, into)
      return [] if records.empty?

      inserter = Inserter.create(table_name: table.to_s, columns: records.first.keys, on_conflict: on_conflict, into: into)
      inserter.insert(records: records)
    end

    class Inserter
      SQL = ::Simple::SQL

      @@inserters = {}

      def self.create(table_name:, columns:, on_conflict:, into:)
        expect! on_conflict => CONFICT_HANDLING.keys

        @@inserters[[table_name, columns, on_conflict, into]] ||= new(table_name: table_name, columns: columns, on_conflict: on_conflict, into: into)
      end

      #
      # - table_name - the name of the table
      # - columns - name of columns, as Array[String] or Array[Symbol]
      #
      def initialize(table_name:, columns:, on_conflict:, into:)
        raise ArgumentError, "Cannot insert a record without attributes" if columns.empty?

        @columns = columns
        @into = into

        cols = []
        vals = []

        cols += columns
        vals += columns.each_with_index.map { |_, idx| "$#{idx + 1}" }

        timestamp_columns = SQL::Reflection.timestamp_columns(table_name) - columns.map(&:to_s)

        cols += timestamp_columns
        vals += timestamp_columns.map { "now()" }

        returning = into ? '*' : "id"

        @sql = "INSERT INTO #{table_name} (#{cols.join(',')}) VALUES(#{vals.join(',')}) #{confict_handling(on_conflict)} RETURNING #{returning}"
      end

      CONFICT_HANDLING = {
        nil      => "",
        :nothing => "ON CONFLICT DO NOTHING",
        :ignore  => "ON CONFLICT DO NOTHING"
      }

      def confict_handling(on_conflict)
        CONFICT_HANDLING.fetch(on_conflict) do
          raise(ArgumentError, "Invalid on_conflict value #{on_conflict.inspect}")
        end
      end

      def insert(records:)
        SQL.transaction do
          records.map do |record|
            SQL.ask @sql, *record.values_at(*@columns), into: @into
          end
        end
      end
    end
  end
end
