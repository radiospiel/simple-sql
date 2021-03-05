class PG::BasicTypeMapForResults < PG::TypeMapByOid
  include PG::BasicTypeRegistry

  class WarningTypeMap < PG::TypeMapInRuby
    def initialize(typenames)
      @already_warned = Hash.new { |h, k| h[k] = {} }
      @typenames_by_oid = typenames
    end

    def typecast_result_value(result, _tuple, field)
      format = result.fformat(field)
      oid = result.ftype(field)
      unless @already_warned[format][oid]
        $stderr.puts "Warning: no type cast defined for type #{@typenames_by_oid[format][oid].inspect} w/oid:#{oid}, format:#{format}. Please cast this type explicitly to TEXT to be safe for future changes."
        @already_warned[format][oid] = true
      end
      super
    end
  end

  def initialize(connection)
    @coder_maps = build_coder_maps(connection)

    # Populate TypeMapByOid hash with decoders
    @coder_maps.flat_map { |f| f[:decoder].coders }.each do |coder|
      add_coder(coder)
    end

    typenames = @coder_maps.map { |f| f[:decoder].typenames_by_oid }
    self.default_type_map = WarningTypeMap.new(typenames)
  end

  # def add_coder(coder)
  #   puts "#{self.class.name}.add_coder #{coder.inspect}"
  #   super
  # end
end

# The ConnectionManager manages a pool of ActiveRecord::Base classes.
#
# ActiveRecord assigns a connection_pool to a class. If you want to connect to
# multiple detabases you must inherit from ActiveRecord::Base. This is what
# we do dynamically in this ConnectionManager.
#
# Note that connections to the same database are always shared within a single
# ConnectionPool.
module Simple::SQL
  module ConnectionManager
    extend self

    def disconnect_all!
      # ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?

      connection_classes = connection_class_by_url.values
      # connection_classes.select(&:connected?).map(&:connection_pool).each(&:disconnect!)
      connection_class_by_url.clear
    end

    def connection_class(url)
      connection_class_by_url[url] ||= create_connection_class(url)
    end

    private

    class StandaloneConnection
      SELF = self

      class << self
        attr_reader :database_url
      end

      class << self
        attr_writer :database_url
      end

      def self.inspect
        "<#{SELF.name} w/url: #{database_url}>"
      end

      def self.connection
        @connection ||= connect!
      end

      class Connection
        attr_reader :raw_connection

        def initialize(raw_connection)
          @raw_connection = raw_connection
        end

        extend Forwardable
        delegate transaction: :raw_connection
      end

      def self.connect!
        parsed = ::Simple::SQL::Config.parse_url(database_url)

        #   extend self
        #
        #   # parse a DATABASE_URL, return PG::Connection settings.
        #   def parse_url(url)
        #
        #
        # PG::Connection.connect_start(host, port, options, tty, dbname, login, password)
        conn = PG.connect(parsed) # url: database_url)

        # require "pry-byebug"
        # binding.pry

        conn.type_map_for_results = type_map_for_results(conn)

        Connection.new(conn)
      end

      def self.type_map_for_results(conn)
        map = PG::BasicTypeMapForResults.new(conn)

        # map.add_coder PG::TextDecoder::JSON.new(oid: 114)   # json
        # map.add_coder PG::TextDecoder::JSON.new(oid: 3802)  # jsonb

        # binding.pry
        # coder = MyPG::BinaryDecoder::JSON.new(oid: 114)

        # map.add_coder MyPG::BinaryDecoder::JSON.new(name: "json", oid: 114)   # json
        # map.add_coder MyPG::BinaryDecoder::JSON.new(name: "jsonb", oid: 3802)  # jsonb

        map.default_type_map = MyPG::DefaultTypeMap.new
        # cast all unknown types into strings.
        # map.default_type_map = PG::TypeMapAllStrings.new
        map

        # for OIDs see here
        # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat
        # map.add_coder
        # register_type 0, 'json', MyPG::TextEncoder::JSON, MyPG::TextDecoder::JSON
        # alias_type    0, 'jsonb',  'json'
      end

      module MyPG
        class DefaultTypeMap < PG::TypeMapInRuby
          def initialize # (typenames)
            # @already_warned = Hash.new{|h, k| h[k] = {} }
            # @typenames_by_oid = typenames
          end

          def typecast_result_value(result, tuple, field)
            encoded = super

            case result.fformat(field)
            when 0 then typecast_text_value(encoded, result, tuple, field)
            when 1 then typecast_binary_value(encoded, result, tuple, field)
            end
          end

          def typecast_text_value(encoded, result, tuple, field)
            puts "typecast_text_value: #{encoded.inspect}"

            unknown_typecast(result, tuple, field)
            # oid = result.ftype(field)
            #             case oid
            #             when -1 then :nop
            #             # when 114 then # json
            #             #   # map.add_coder PG::TextDecoder::JSON.new(oid: 114)   # json
            #             #   # map.add_coder PG::TextDecoder::JSON.new(oid: 3802)  # jsonb
            #             #
            #             # when 3802 then
            #             else
            #               unknown_typecast(result, tuple,field)
            #             end
          end

          def typecast_binary_value(encoded, result, tuple, field)
            if encoded.each_byte.first == 1
              encoded = encoded.byteslice(1..-1)
            end

            oid = result.ftype(field)
            case oid
            when 114 then # json
              JSON.load(encoded)
            when 3802 then
              JSON.load(encoded)
            else
              unknown_typecast(result, tuple, field)
              encoded
            end
          end

          def unknown_typecast(result, tuple, field)
            oid = result.ftype(field)
            format = result.fformat(field)

            $stderr.puts "Warning: no type cast defined for type w/oid:#{oid}, format:#{format}, tuple: #{tuple}. Please cast this type explicitly to TEXT to be safe for future changes."
            result
            end
          end
        end
      end
    #   module MyPG::BinaryEncoder
    #     class JSON < PG::SimpleEncoder
    #       def encode(string, tuple=nil, field=nil)
    #         ::JSON.dump(value)
    #       end
    #     end
    #   end
    #   module MyPG::BinaryDecoder
    #     class JSON < PG::SimpleDecoder
    #       def format
    #         1
    #       end
    #
    #       def decode(string, tuple=nil, field=nil)
    #         ::JSON.load(string)
    #       end
    #     end
    #   end
    #   # module MyPG::BinaryDecoder; end
    # end

    def connection_class_by_url
      @connection_class_by_url ||= {}
    end

    def create_connection_class(url)
      Class.new(StandaloneConnection).tap do |klass|
        klass.database_url = url
        # klass.name = "Simple::SQL::Connection::StandaloneConnection::Adapter/#{url}"

        # raise klass.name
        # klass.establish_connection url
        # connection_pool = klass.connection_pool
        # connection_pool_stats = {
        #   size: connection_pool.size,
        #   automatic_reconnect: connection_pool.automatic_reconnect,
        #   checkout_timeout: connection_pool.checkout_timeout
        # }
        # ::Simple::SQL.logger.info "#{URI.without_password url}: connected to connection pool w/#{connection_pool_stats.inspect}"
      end
    end

    # # ActiveRecord needs a class name in order to connect.
    # module WritableClassName
    #   attr_accessor :name0
    # end
    #
    # def create_connection_class(url)
    #   Class.new(ActiveRecord::Base).tap do |klass|
    #     klass.extend WritableClassName
    #     klass.name = "Simple::SQL::Connection::ExplicitConnection::Adapter/#{url}"
    #
    #     klass.establish_connection url
    #     connection_pool = klass.connection_pool
    #     connection_pool_stats = {
    #       size: connection_pool.size,
    #       automatic_reconnect: connection_pool.automatic_reconnect,
    #       checkout_timeout: connection_pool.checkout_timeout
    #     }
    #     ::Simple::SQL.logger.info "#{URI.without_password url}: connected to connection pool w/#{connection_pool_stats.inspect}"
    #   end
    # end
  end
end

module URI
  def self.without_password(uri)
    uri = URI.parse(uri) unless uri.is_a?(URI)
    uri = uri.dup
    uri.password = "*" * uri.password.length if uri.password
    uri
  end
end
