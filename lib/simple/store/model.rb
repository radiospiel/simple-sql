# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/AbcSize

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

# This class implements a Hash-like object, which will resolves attributes via
# method_missing, using the implementations as specified in the object's metamodel.
class Simple::Store::Model
  def new_record?
    id.nil?
  end

  attr_reader :metamodel
  attr_reader :to_hash

  def to_json(*args)
    to_hash.to_json(*args)
  end

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

  # Build a model of a given \a metamodel.
  #
  # The constructor assumes that all attributes in +trusted_data+ are valid and
  # of the right type. No validation happens here. This is the case when reading
  # from the storage.

  def initialize(metamodel, trusted_data: {})
    expect! trusted_data => { "type" => [nil, metamodel.name] }

    @metamodel        = metamodel
    @to_hash          = trusted_data.stringify_keys
    @to_hash["type"]  = metamodel.name
    @to_hash["id"] ||= nil
  end

  private

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
  # [TODO]: Attributes are converted as necessary.
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

    @to_hash.merge!(attrs)
    self
  end

  # compare this model with another model or Hash.
  #
  # This ignores Symbol/String differences.
  def ==(other)
    return false unless other.respond_to?(:to_hash)

    to_hash == other.to_hash.stringify_keys
  end

  def inspect
    hsh = to_hash.reject { |k, _v| %w(id type meta_data).include?(k) }

    hsh = hsh.reject do |k, v|
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
    (sym =~ GETTER_OR_SETTER) && metamodel.attribute?($1)
  end

  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockNesting
  # rubocop:disable Style/GuardClause

  # ^^^ Please keep the code for method_missing as convoluted as it is.
  #     It needs a certain level of mental agility to read and adjust.
  def method_missing(sym, *args)
    case args.length
    when 0
      if GETTER_REGEXP =~ sym
        attr = metamodel.attributes[$1]
        if attr
          if attr[:kind] == :virtual
            return metamodel.resolve_virtual_attribute(self, $1)
          else
            return @to_hash[$1]
          end
        end
      end
    when 1
      if SETTER_REGEXP =~ sym && metamodel.writable_attribute?($1)
        return @to_hash[$1] = args[0]
      end
    end

    super
  end
end
