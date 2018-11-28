class Simple::Store::Metamodel; end

require_relative "metamodel/registry"

# rubocop:disable Metrics/ClassLength
class Simple::Store::Metamodel
  SELF = self
  NAME_REGEXP = /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*\z/

  Model = ::Simple::Store::Model

  def self.register(name, table_name:, &block)
    expect! name => /^[A-Z]/
    expect! table_name => String

    metamodel = new(name: name, table_name: table_name, &block)

    Registry.register(metamodel)
  end

  def self.register_virtual_attributes(name, &block)
    resolve(name).register_virtual_attributes(&block)
  end

  def self.unregister(name)
    Registry.unregister(name)
  end

  # Casts the \a name_or_metamodel parameter into a Metamodel object.
  def self.resolve(name_or_metamodel)
    if name_or_metamodel.is_a?(Array)
      return name_or_metamodel.map { |m| resolve(m) }
    end

    expect! name_or_metamodel => [String, self]

    if name_or_metamodel.is_a?(String)
      Registry.lookup(name_or_metamodel)
    else
      name_or_metamodel
    end
  end

  # The name of the Metamodel
  attr_reader :name

  # The name of the backing database table
  attr_reader :table_name

  OPTIONS_DEFAULTS = {
    readable: true,
    writable: true,
    kind: :dynamic,
    type: :text
  }

  # register an attribute
  def attribute(name, options)
    name = name.to_s

    current_options = @attributes[name] || OPTIONS_DEFAULTS
    options = current_options.merge(options)
    if options[:kind] == :virtual
      options[:writable] = false
    end

    @attributes[name] ||= {}
    @attributes[name].merge!(options)

    @filtered_attributes&.clear # see attributes method

    self
  end

  def register_virtual_attributes(&block)
    @virtual_attributes ||= Module.new
    @virtual_attributes.instance_eval(&block)
    self
  end

  # returns an object which has implementations for virtual attributes mixed in.
  def virtual_implementations
    @virtual_attributes
  end

  def resolve_virtual_attribute(model, name)
    @virtual_attributes.send(name, model)
  end

  # A hash mapping attribute names to attribute specifications.
  # attr_reader :attributes # Hash name -> {}

  def attributes(filter = nil)
    return @attributes if filter.nil?

    @filtered_attributes ||= {}
    @filtered_attributes[filter] ||= begin
      expect! filter => {
        dynamic: [true, false, nil],
        static: [true, false, nil]
      }

      @attributes.select do |_name, options|
        filter.all? do |filter_name, filter_value|
          next true if filter_value.nil?
          next true if options[filter_name] == filter_value
          false
        end
      end
    end
  end

  def attribute?(name)
    attributes.key?(name)
  end

  def writable_attribute?(name)
    attributes(writable: true).key?(name)
  end

  def build(hsh)
    Model.new(self).assign(hsh)
  end

  # Validate a model
  def validate!(_model)
    :nop
  end

  def initialize(attrs, &block)
    expect! attrs => {
      name: [NAME_REGEXP, nil],
      table_name: String
    }

    name, table_name = attrs.values_at :name, :table_name

    @attributes = {}
    @name = name || table_name.split(".").last.singularize.camelize
    @table_name = table_name

    read_attributes_from_table

    instance_eval(&block) if block
  end

  private

  def column_info
    column_info = Simple::SQL::Reflection.column_info(table_name)
    raise ArgumentError, "No such table #{table_name.inspect}" if column_info.empty?
    column_info
  end

  public

  def column?(name)
    column_info.key? name
  end

  private

  TYPE_BY_PG_DATA_TYPE = {
    "character varying" => :text,
    "timestamp without time zone"  => :timestamp,
    "USER-DEFINED"                 => :string # enums
  }

  READONLY_ATTRIBUTES = %(created_at updated_at id type)

  def read_attributes_from_table
    column_info.each do |name, ostruct|
      next if name == "metadata"

      data_type = ostruct.data_type

      attribute name,
                type:     (TYPE_BY_PG_DATA_TYPE[data_type] || data_type.to_sym),
                writable: !READONLY_ATTRIBUTES.include?(name),
                readable: true,
                kind:     :static
    end
  end
end
