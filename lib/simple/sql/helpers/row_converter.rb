module Simple::SQL::Helpers::RowConverter
  # returns an array of converted records
  def self.convert(records, into:)
    hsh = records.first
    return records unless hsh

    if into == :struct
      converter = StructConverter.for(attributes: hsh.keys)
      records.map { |record| converter.convert(record) }
    else
      records.map { |record| into.new(record) }
    end
  end

  class StructConverter # :nodoc:
    def self.for(attributes:)
      @cache ||= {}
      @cache[attributes] ||= new(attributes)
    end

    private

    def initialize(attributes)
      @klass = Struct.new(*attributes)
    end

    public

    def convert(hsh)
      values = hsh.values_at(*@klass.members)
      @klass.new(*values)
    end
  end
end
