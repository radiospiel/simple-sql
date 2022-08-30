# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity

# private
module Simple::SQL::TablePrint
  extend self

  ROW_SEPARATOR = " | "

  def table_print(records, io: STDOUT, width: :auto)
    # check args

    return if records.empty?

    column_count = records.first.length
    return if column_count == 0

    # -- determine/adjust total width for output. -----------------------------

    width = terminal_width(io) if width == :auto
    width = nil if width && width <= 0

    # -- prepare printing -----------------------------------------------------

    rows = materialize_rows(records)
    column_widths = column_max_lengths(rows)

    if width
      column_widths = distribute_column_widths(column_widths, width, column_count, rows.first)
    end

    # -- print ----------------------------------------------------------------

    print_records(rows, io, column_widths)
  end

  private

  def terminal_width(io)
    return unless io.isatty

    `tput cols`.to_i
  rescue Errno::ENOENT
    nil
  end

  def materialize_rows(records)
    keys = records.first.keys

    rows = []
    rows << keys.map(&:to_s)
    records.each do |rec|
      rows << rec.values_at(*keys).map(&:to_s)
    end
    rows
  end

  def column_max_lengths(rows)
    rows.inject([0] * rows.first.length) do |ary, row|
      ary.zip(row.map(&:length)).map(&:max)
    end
  end

  MIN_COLUMN_WIDTH = 7

  # rubocop:disable Metrics/PerceivedComplexity
  def distribute_column_widths(column_widths, total_chars, column_count, title_row)
    # caluclate available width: this is the number of characters available in
    # total, reduced by the characters "wasted" for row separators.
    available_chars = total_chars - (column_count - 1) * ROW_SEPARATOR.length

    return column_widths if available_chars <= 0

    required_chars = column_widths.sum
    return column_widths if required_chars < total_chars

    # [TODO] The algorithm below produces ok-ish results - but usually misses a few characters
    # that could still be assigned a column. To do this we shuld emply D'Hondt or something
    # similar.

    # -- initial setup --------------------------------------------------------
    #
    # We guarantee each column a minimum number of characters of MIN_COLUMN_WIDTH.
    # If the column does not need that many characters, it will only be allocated
    # the number of characters that are really necessary.
    #
    # If necessary we then extend a column to fit its title.

    result = [MIN_COLUMN_WIDTH] * column_count
    result = result.zip(column_widths).map(&:min)
    result = result.zip(title_row).map { |r, title| [r, title.length].max }

    # -- return if there are no more characters available ---------------------

    # This happens if the terminal is **way** to narrow.
    return column_widths if result.sum > available_chars

    # -- distribute unassigned characters -------------------------------------

    unassigned_widths = column_widths.zip(result).sum { |cw, r| cw - r }
    if unassigned_widths > 0
      available_space = available_chars - result.sum
      if available_space > 0

        result = result.zip(column_widths).map do |r, cw|
          r + (cw - r) * available_space / unassigned_widths
        end
      end
    end

    # [TODO] We can still have available characters at this point.
    # unassigned_chars = available_chars - result.sum

    result
  end

  def format_value(value, width)
    if value.length < width
      "%-#{width}s" % value
    elsif value.length == width
      value
    else
      value[0, width - 1] + "…"
    end
  end

  def print_records(rows, io, column_widths)
    rows.each_with_index do |row, idx|
      parts = row.zip(column_widths).map do |value, col_width|
        format_value value, col_width
      end

      io.puts parts.join(ROW_SEPARATOR)

      if idx == 0
        io.puts parts.join(ROW_SEPARATOR).gsub(/[^|]/, "-")
      end
    end
  end
end
