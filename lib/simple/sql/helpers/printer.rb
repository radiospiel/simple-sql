# rubocop:disable Metrics/AbcSize

# private
module Simple::SQL::Helpers::Printer
  extend self

  def print(records)
    if table_print?
      tp records
    else
      lp records
    end
  end

  def lp(records)
    return if records.empty?

    keys = records.first.keys
    return if keys.empty?

    rows = []
    rows << keys

    records.each do |rec|
      rows << rec.values_at(*keys).map(&:to_s)
    end

    max_lengths = rows.inject([0] * keys.count) do |ary, row|
      ary.zip(row.map(&:length)).map(&:max)
    end

    rows.each_with_index do |row, idx|
      parts = row.zip(max_lengths).map do |value, max_length|
        " %-#{max_length}s " % value
      end

      STDERR.puts parts.join("|")

      if idx == 0
        STDERR.puts parts.join("|").gsub(/[^|]/, "-")
      end
    end
  end

  def table_print?
    load_table_print unless instance_variable_defined? :@table_print
    @table_print
  end

  def load_table_print
    require "table_print"
    @table_print = true
  rescue LoadError
    @table_print = false
  end
end
