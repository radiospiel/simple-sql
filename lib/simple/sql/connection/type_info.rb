# rubocop:disable Style/SymbolLiteral
# rubocop:disable Style/HashSyntax

# This module implements an adapter between the Simple::SQL interface
# (i.e. ask, all, first, transaction) and a raw connection.
#
# This module can be mixed onto objects that implement a raw_connection
# method, which must return a Pg::Connection.

class Simple::SQL::Connection
  def type_info
    @type_info ||= TypeInfo.new(self)
  end

  class TypeInfo
    def initialize(connection)
      @connection = connection
    end

    # returns a Symbol
    def pg_type_name(ftype:, fmod:)
      @pg_type_names ||= {}
      @pg_type_names[[ftype, fmod]] ||= _pg_type_name(ftype, fmod)
    end

    # returns a Symbol
    def type_name(ftype:, fmod:)
      @type_names ||= {}
      @type_names[[ftype, fmod]] ||= _type_name(ftype, fmod)
    end

    private

    TYPE_NAMES = {
      :unknown                       => :"string",
      :"character varying"           => :"string",
      :integer                       => :"integer",
      :bigint                        => :"integer",
      :numeric                       => :"float",
      :"double precision"            => :"float",
      :"integer[]"                   => :"integer[]",
      :"character varying[]"         => :"string[]",
      :"text[]"                      => :"string[]",
      :"timestamp without time zone" => :"time",
      :"timestamp with time zone"    => :"time",
      :hstore                        => :"object",
      :json                          => :"object",
      :jsonb                         => :"object",
      :boolean                       => :"boolean"
    }

    def _pg_type_name(ftype, fmod)
      @connection.raw_connection.exec("SELECT format_type($1,$2)", [ftype, fmod]).getvalue(0, 0).to_sym
    end

    def _type_name(ftype, fmod)
      pg_type_name = pg_type_name(ftype: ftype, fmod: fmod)
      TYPE_NAMES[pg_type_name] || _custom_type_name(ftype, fmod, pg_type_name)
    end

    def _custom_type_name(_ftype, _fmod, pg_type_name)
      "UNKNWON #{pg_type_name.inspect}".to_sym
    end
  end
end
