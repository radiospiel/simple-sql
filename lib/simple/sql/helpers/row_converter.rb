require_relative "./immutable"
require_relative "../reflection"

module Simple::SQL::Helpers::RowConverter
  SELF = self

  Reflection = ::Simple::SQL::Reflection

  # returns an array of converted records
  def self.convert_row(records, into:, associations: nil, fq_table_name: nil)
    hsh = records.first
    return records unless hsh

    converter = build_converter(hsh, into: into, associations: associations, fq_table_name: fq_table_name)
    records.map { |record| converter.convert_row(record) }
  end

  # This method builds and returns a converter object which provides a convert_row method.
  # which in turn is able to convert a Hash (the row as read from the query) into the
  # target type +into+
  #
  # The into: parameter designates the target type. The following scenarios are supported:
  #
  # 1. Converting into Structs (into == :struct)
  #
  # Converts records into a dynamically created struct. This has the advantage of being
  # really fast.
  #
  # 2. Converting into Immutables (into == :immutable)
  #
  # Converts records into a Immutable object. The resulting objects implement getters for all
  # existing attributes, including embedded arrays and hashes, but do not offer setters -
  # resulting in de-facto readonly objects.
  #
  # 3. Custom targets based on table name
  #
  # If an object is passed in that implements a "from_complete_row" method, and the query
  # results are complete - i.e. all columns in the underlying table (via fq_table_name)
  # are in the resulting records - this mode uses the +into+ object's +from_complete_row+
  # method to convert the records. This mode is used by Simple::Store.
  #
  # If the records are not complete, and contain more than a single value this mode behaves
  # like <tt>:immutable</tt>.
  #
  # If the records are not complete and contain only a single value this mode returns that
  # value for each record.
  #
  # 4. Other custom types
  #
  # If an object is passed in that does not implement "from_complete_row" the object's
  # +new+ method is called on each row's hash. This allows to run queries against all classes
  # that can be built from a Hash, for example OpenStructs.
  def self.build_converter(hsh, into:, associations: nil, fq_table_name: nil)
    case into
    when :struct
      StructConverter.for(attributes: hsh.keys, associations: associations)
    when :immutable
      ImmutableConverter.new(type: into, associations: associations)
    else
      build_custom_type_converter(hsh, into: into, associations: associations, fq_table_name: fq_table_name)
    end
  end

  def self.build_custom_type_converter(hsh, into:, associations: nil, fq_table_name: nil)
    # If the into object does not provide a :from_complete_row method, we'll use
    # a converter that creates objects via ".new"
    unless into.respond_to?(:from_complete_row)
      return TypeConverter.new(type: into, associations: associations)
    end

    # If the query results are complete we'll use the into object
    required_columns = Reflection.columns(fq_table_name)
    actual_columns   = hsh.keys.map(&:to_s)

    if (required_columns - actual_columns).empty?
      return CompleteRowConverter.new(type: into, associations: associations, fq_table_name: fq_table_name)
    end

    # If the query only has a single value we'll extract the value
    return SingleValueConverter.new if hsh.count == 1

    # Otherwise we'll fall back to :immutable
    ImmutableConverter.new(type: into, associations: associations)
  end

  def self.convert(record, into:) # :nodoc:
    ary = convert_row([record], into: into)
    ary.first
  end

  class SingleValueConverter
    def convert_row(hsh)
      hsh.values.first
    end
  end

  class TypeConverter #:nodoc:
    def initialize(type:, associations:)
      @type         = type
      @associations = associations
    end

    def convert_row(hsh)
      hsh = convert_associations(hsh) if @associations
      build_row_in_target_type hsh
    end

    def build_row_in_target_type(hsh)
      @type.new hsh
    end

    def convert_associations(hsh)
      updates = {}

      @associations.each do |key|
        value = hsh.fetch(key)
        case value
        when Hash   then updates[key] = SELF.convert(value, into: @type)
        when Array  then updates[key] = SELF.convert_row(value, into: @type)
        end
      end

      hsh.merge(updates)
    end
  end

  class ImmutableConverter < TypeConverter #:nodoc:
    Immutable = ::Simple::SQL::Helpers::Immutable

    def build_row_in_target_type(hsh)
      Immutable.create hsh
    end
  end

  class CompleteRowConverter < TypeConverter #:nodoc:
    def initialize(type:, associations:, fq_table_name:)
      super(type: type, associations: associations)
      @fq_table_name = fq_table_name
    end

    def convert_row(hsh)
      hsh = convert_associations(hsh) if @associations
      @type.from_complete_row hsh, fq_table_name: @fq_table_name
    end
  end

  class StructConverter # :nodoc:
    def self.for(attributes:, associations:)
      @cache ||= {}
      @cache[[attributes, associations]] ||= new(attributes: attributes, associations: associations)
    end

    def initialize(attributes:, associations:)
      @attributes          = attributes
      @associations        = associations
      @association_indices = associations.map { |association| attributes.index(association) } if associations

      @klass = Struct.new(*attributes)
    end

    def convert_row(hsh)
      values = hsh.values_at(*@attributes)

      convert_associations(values) if @associations
      @klass.new(*values)
    end

    # convert values at the <tt>@association_indices</tt>.
    def convert_associations(values)
      @association_indices.each do |idx|
        value = values[idx]
        case value
        when Hash   then values[idx] = SELF.convert(value, into: :struct)
        when Array  then values[idx] = SELF.convert_row(value, into: :struct)
        end
      end
    end
  end
end
