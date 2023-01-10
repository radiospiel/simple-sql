require "time"

# private
module Simple::SQL::Helpers::Decoder
  extend self

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Style/MultipleComparison
  def decode_value(type, s)
    case type
    when :unknown                       then s
    when :'character varying'           then s
    when :integer                       then Integer(s)
    when :bigint                        then Integer(s)
    when :numeric                       then Float(s)
    when :'double precision'            then Float(s)
    when :'integer[]'                   then s.scan(/-?\d+/).map { |part| Integer(part) }
    when :'character varying[]'         then parse_pg_array(s)
    when :'text[]'                      then parse_pg_array(s)
    when :'timestamp without time zone' then decode_time(s)
    when :'timestamp with time zone'    then decode_time(s)
    when :hstore                        then HStore.parse(s)
    when :json                          then ::JSON.parse(s)
    when :jsonb                         then ::JSON.parse(s)
    when :boolean                       then s == "t" || s == true
    else
      # unknown value, we just return the string here.
      # STDERR.puts "unknown type: #{type.inspect}"
      s
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Style/MultipleComparison

  require "pg_array_parser"
  extend PgArrayParser

  def decode_time(s)
    return s if s.is_a?(Time)

    ::Time.parse(s)
  end

  # HStore parsing
  module HStore
    extend self

    # thanks to https://github.com/engageis/activerecord-postgres-hstore for regexps!

    QUOTED_LITERAL    = /"[^"\\]*(?:\\.[^"\\]*)*"/
    UNQUOTED_LITERAL  = /[^\s=,][^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
    LITERAL           = /(#{QUOTED_LITERAL}|#{UNQUOTED_LITERAL})/
    PAIR              = /#{LITERAL}\s*=>\s*#{LITERAL}/
    NULL              = /\ANULL\z/i
    DOUBLE_QUOTE      = '"'.freeze
    ESCAPED_CHAR      = /\\(.)/

    def parse(hstore)
      hstore.scan(PAIR).each_with_object({}) do |(k, v), memo|
        k = unpack(k)
        k = k.to_sym
        v = v =~ NULL ? nil : unpack(v)
        memo[k] = v
      end
    end

    def unpack(string)
      string = string[1..-2] if string[0] == DOUBLE_QUOTE # remove quotes, if any
      string.gsub ESCAPED_CHAR, '\1'                      # unescape, if necessary
    end
  end
end

module Simple::SQL::Helpers::Decoder
  def self.new(result, into:, column_info:)
    if into == Hash           then HashRecord.new(column_info)
    elsif result.nfields == 1 then SingleColumn.new(column_info)
    else
      MultiColumns.new(column_info)
    end
  end

  class SingleColumn
    def initialize(column_info)
      @field_type = column_info.first.fetch(:pg_type_name)
    end

    def decode(row)
      value = row.first
      value && Simple::SQL::Helpers::Decoder.decode_value(@field_type, value)
    end
  end

  class MultiColumns
    H = ::Simple::SQL::Helpers

    def initialize(column_info)
      @field_types = H.pluck(column_info, :pg_type_name)
    end

    def decode(row)
      @field_types.zip(row).map do |field_type, value|
        value && Simple::SQL::Helpers::Decoder.decode_value(field_type, value)
      end
    end
  end

  class HashRecord < MultiColumns
    H = ::Simple::SQL::Helpers

    def initialize(column_info)
      super(column_info)
      @field_names = H.pluck(column_info, :name)
    end

    def decode(row)
      decoded_row = super(row)
      @field_names.zip(decoded_row).to_h
    end
  end
end
