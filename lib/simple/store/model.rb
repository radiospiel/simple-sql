# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/AbcSize

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

class Simple::Store::Model
  def new_record?
    id.nil?
  end

  attr_reader :metamodel
  attr_reader :to_hash

  # Returns a hash of changed attributes indicating their original and new values
  # like attr => [original value, new value].
  #
  #   person.diff # => {}
  #   person.name = 'bob'
  #   person.diff # => { "name" => ["bill", "bob"] }
  #
  # Note that no changes are returned if the record hasn't been saved.
  #
  # def diff
  #   return {} unless @original_hash
  #
  #   @to_hash.each_with_object({}) do |(key, value), diff|
  #     original_value = @original_hash[key]
  #     next if !original_value.nil? && original_value == value
  #     next if original_value.nil? && !@original_hash.key?(key)
  #
  #     diff[key] = [original_value, value]
  #   end
  # end

  private

  # Build a model of a given \a metamodel.
  #
  # The constructor assumes that all attributes in +trusted_data+ are valid and
  # of the right type. No validation happens here. This is the case when reading
  # fro the storage.
  def initialize(metamodel, trusted_data: {})
    expect! trusted_data => { "type" => [nil, metamodel.name] }

    @metamodel        = metamodel
    @to_hash          = trusted_data.stringify_keys
    @to_hash["type"]  = metamodel.name
    @to_hash["id"] ||= nil

    metamodel.attributes(kind: :virtual).each_key do |name|
      @to_hash[name] = metamodel.virtual_implementations.send(name, self)
    end

    # puts base.public_methods(fal)
  end

  def set_id_by_trusted_caller(id) # rubocop:disable Naming/AccessorMethodName
    expect! id => Integer
    @to_hash["id"] = id
  end

  public

  # Assign many attributes at once.
  #
  # This method ignores attributes that are not defined for models of this
  # type.
  #
  # Attributes are converted as necessary. See #convert_types.
  def assign(attrs)
    expect! attrs => Hash

    attrs = attrs.stringify_keys

    attrs.delete_if do |key, _value|
      %w(id type created_at updated_at).include?(key)
    end

    # -- apply write-protection

    write_protected_attributes = metamodel.attributes(writable: false)

    attrs.delete_if do |key, _value|
      write_protected_attributes.key?(key)
    end

    # -- convert types fro String values into target type

    attrs = convert_types(attrs)

    @to_hash.merge!(attrs)
    self
  end

  private

  # stringify keys in attrs, and convert as necessary.
  #
  # Conversion only happens if an input value is a String, and the attribute
  # is not of type :text.
  #
  # Also removes all unknown attributes, and internal attributes.
  #
  # Returns a new or a potentially changed Hash
  def convert_types(attrs)
    attrs
  end

  public

  # compare this record with another record.
  #
  # This compares against a Hash representation of \a other. Consequently you
  # can compare a Record against another Record, but also against a Hash.
  def ==(other)
    return false unless other.respond_to?(:to_hash)

    to_hash == other.to_hash.stringify_keys
  end

  def inspect
    hsh = to_hash.reject { |k, _v| %w(id type metadata).include?(k) }

    hsh.reject! do |k, v|
      v.nil? && metamodel.attributes[k] && metamodel.attributes[k][:kind] == :dynamic
    end

    inspected_values = hsh.map { |k, v| "#{k}: #{v.inspect}" }.sort

    identifier = "#{metamodel.name}##{id.inspect}"
    inspected_values.empty? ? "<#{identifier}>" : "<#{identifier}: #{inspected_values.join(', ')}>"
  end

  private

  GETTER_REGEXP    = /\A([a-z_][a-z0-9_]*)\z/
  SETTER_REGEXP    = /\A([a-z_][a-z0-9_]*)=\z/
  GETTER_OR_SETTER = /\A([a-z_][a-z0-9_]*)(=?)\z/

  def respond_to_missing?(sym, _include_private = false)
    (sym =~ GETTER_OR_SETTER) && attribute?($1)
  end

  def method_missing(sym, *args)
    case args.length
    when 0
      if GETTER_REGEXP =~ sym && attribute?($1)
        return get_attribute($1)
      end
    when 1
      if SETTER_REGEXP =~ sym && writable_attribute?($1)
        return set_attribute($1, args[0])
      end
    end

    super
  end

  def attribute?(name)
    metamodel.attributes.key?(name)
  end

  def writable_attribute?(name)
    metamodel.attributes(writable: true).key?(name)
  end

  def get_attribute(name)
    @to_hash[name]
  end

  def set_attribute(name, value)
    # @original_hash ||= @to_hash.deep_dup

    @to_hash[name] = value
  end
end
