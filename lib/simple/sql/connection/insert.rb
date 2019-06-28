# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/LineLength

class Simple::SQL::Connection
  #
  # - table_name - the name of the table
  # - records - a single hash of attributes or an array of hashes of attributes
  # - on_conflict - uses a postgres ON CONFLICT clause to ignore insert conflicts if true
  #
  def insert(table, records, on_conflict: nil, into: nil)
    if records.is_a?(Hash)
      inserted_records = insert(table, [records], on_conflict: on_conflict, into: into)
      return inserted_records.first
    end

    return [] if records.empty?

    inserter = inserter(table_name: table.to_s, columns: records.first.keys, on_conflict: on_conflict, into: into)
    inserter.insert(records: records)
  end

  private

  def inserter(table_name:, columns:, on_conflict:, into:)
    @inserters ||= {}
    @inserters[[table_name, columns, on_conflict, into]] ||= Inserter.new(self, table_name, columns, on_conflict, into)
  end

  class Inserter
    CONFICT_HANDLING = {
      nil      => "",
      :nothing => "ON CONFLICT DO NOTHING",
      :ignore  => "ON CONFLICT DO NOTHING"
    }

    #
    # - table_name - the name of the table
    # - columns - name of columns, as Array[String] or Array[Symbol]
    #
    def initialize(connection, table_name, columns, on_conflict, into)
      expect! on_conflict => CONFICT_HANDLING.keys
      raise ArgumentError, "Cannot insert a record without attributes" if columns.empty?

      @connection = connection
      @columns = columns
      @into = into

      cols = []
      vals = []

      cols += columns
      vals += columns.each_with_index.map { |_, idx| "$#{idx + 1}" }

      timestamp_columns = @connection.reflection.timestamp_columns(table_name) - columns.map(&:to_s)

      cols += timestamp_columns
      vals += timestamp_columns.map { "now()" }

      returning = into ? "*" : "id"

      @sql = "INSERT INTO #{table_name} (#{cols.join(',')}) VALUES(#{vals.join(',')}) #{CONFICT_HANDLING[on_conflict]} RETURNING #{returning}"
    end

    def insert(records:)
      @connection.transaction do
        records.map do |record|
          @connection.ask @sql, *record.values_at(*@columns), into: @into
        end
      end
    end
  end
end
