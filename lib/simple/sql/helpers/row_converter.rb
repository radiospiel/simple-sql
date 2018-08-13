module Simple::SQL::Helpers::RowConverter # :private:
  SELF = self

  # returns an array of converted records
  def self.convert_ary(records, into:)
    hsh = records.first
    return records unless hsh

    converter = if into == :struct
                  StructConverter.for(attributes: hsh.keys)
                else
                  TypeConverter.for(type: into)
                end

    records.map { |record| converter.convert_ary(record) }
  end

  def self.convert(record, into:) # :nodoc:
    ary = convert_ary([record], into: into)
    ary.first
  end

  class TypeConverter #:nodoc:
    def self.for(type:)
      new(type: type)
    end

    def initialize(type:)
      @type = type
    end

    def convert_ary(hsh)
      updates = {}
      hsh.each do |key, value|
        case value
        when Hash   then updates[key] = SELF.convert(value, into: @type)
        when Array  then updates[key] = SELF.convert_ary(value, into: @type)
        end
      end

      hsh = hsh.merge(updates)

      @type.new hsh
    end
  end

  class StructConverter # :nodoc:
    def self.for(attributes:)
      @cache ||= {}
      @cache[attributes] ||= new(attributes)
    end

    def initialize(attributes)
      @klass = Struct.new(*attributes)
    end

    def convert_ary(hsh)
      values = hsh.values_at(*@klass.members)
      updates = {}

      values.each_with_index do |value, idx|
        case value
        when Hash   then updates[idx] = SELF.convert(value, into: :struct)
        when Array  then updates[idx] = SELF.convert_ary(value, into: :struct)
        end
      end

      updates.each do |idx, updated_value|
        values[idx] = updated_value
      end

      @klass.new(*values)
    end
  end
end
