# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

# private
module Simple::SQL::Helpers::Printer
  extend self

  ROW_SEPARATOR = " | "

  def self.print(records, io: STDOUT, width: :auto)
    # check args

    return if records.empty?
    return if records.first.keys.empty?

    if width == :auto && io.isatty
      width = `tput cols`.to_i
    end
    width = nil if width && width <= 0

    # prepare printing

    rows = materialize_rows(records)
    column_widths = calculate_column_widths(rows)
    column_widths = optimize_column_widths(column_widths, width, rows.first.length) if width

    # print

    print_records(rows, io, column_widths)
  end

  private

  def materialize_rows(records)
    keys = records.first.keys

    rows = []
    rows << keys.map(&:to_s)
    records.each do |rec|
      rows << rec.values_at(*keys).map(&:to_s)
    end
    rows
  end

  def calculate_column_widths(rows)
    rows.inject([0] * rows.first.length) do |ary, row|
      ary.zip(row.map(&:length)).map(&:max)
    end
  end

  def optimize_column_widths(column_widths, width, column_count)
    required_width = column_widths.sum + column_count * ROW_SEPARATOR.length
    overflow = required_width - width
    return column_widths if overflow <= 0

    # TODO: Use d'hondt with a minimum percentage for a fairer distribution
    # The following is just a quick hack...
    overflow += 40

    column_widths.map do |col_width|
      (col_width - overflow * col_width * 1.0 / required_width).to_i
    end
  end

  def print_records(rows, io, column_widths)
    rows.each_with_index do |row, idx|
      parts = row.zip(column_widths).map do |value, col_width|
        s = "%-#{col_width}s " % value
        s[0..col_width]
      end

      io.puts parts.join(ROW_SEPARATOR)

      if idx == 0
        io.puts parts.join(ROW_SEPARATOR).gsub(/[^|]/, "-")
      end
    end
  end
end
