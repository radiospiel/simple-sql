# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize

module Simple
  module SQL
    def duplicate(table, ids, except: [])
      ids = Array(ids)
      return [] if ids.empty?

      timestamp_columns = Reflection.timestamp_columns(table)
      primary_key_columns = Reflection.primary_key_columns(table)

      # duplicate all columns in the table that need to be SELECTed.
      #
      columns_to_dupe = Reflection.columns(table)

      # Primary keys will not be selected from the table, they should be set
      # automatically by the database, via a DEFAULT role on the column.
      columns_to_dupe -= primary_key_columns

      # timestamp_columns will not be selected from the table, they will be
      # set to now() explicitely.
      columns_to_dupe -= timestamp_columns

      # If some other columns must be excluded they have to be added in the
      # except: keyword argument. This is helpful for UNIQUE columns, but
      # a column which is supposed to be UNIQUE and NOT NULL can not be dealt
      # with.
      columns_to_dupe -= except.map(&:to_s)

      # build query
      select_columns = columns_to_dupe + timestamp_columns
      select_values  = columns_to_dupe + timestamp_columns.map { |col| "now() AS #{col}" }

      Simple::SQL.all <<~SQL, ids
        INSERT INTO #{table}(#{select_columns.join(', ')})
        SELECT #{select_values.join(', ')} FROM #{table} WHERE id = ANY($1) RETURNING id
      SQL
    end
  end
end
