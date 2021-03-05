require "time"

module Simple::SQL::Helpers::Decoder
  extend self
  # rubocop:disable Naming/UncommunicativeMethodParamName
  def decode_value(type, s)
    return s unless s.is_a?(String)

    case type
    # when :numeric                       then Float(s)
    # when :'integer[]'                   then s.scan(/-?\d+/).map { |part| Integer(part) }
    # when :"character varying[]"         then parse_pg_array(s)
    # when :"text[]"                      then parse_pg_array(s)
    when :hstore                        then HStore.parse(s)
    # when :json                          then ::JSON.parse(s)
    # when :jsonb                         then ::JSON.parse(s)
    else
      # unknown value, we just return the string here.
      # STDERR.puts "unknown type: #{type.inspect}"
      s
    end
  end

  require "pg_array_parser"
  extend PgArrayParser

  module HStore
    # On performance: ActiveRecord parses HStore like this:
    #
    # ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Hstore.new.deserialize(str)
    #
    # but this has half the performance of our solution.
    #
    # There is also a "PgHstore" gem, see https://github.com/seamusabshere/pg-hstore,
    # which is on par with Simple-SQLs solution.

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
    else                           MultiColumns.new(column_info)
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
      Hash[@field_names.zip(decoded_row)]
    end
  end
end
