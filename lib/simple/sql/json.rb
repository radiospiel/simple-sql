# rubocop:disable Style/DoubleNegation

# This class implements lazy JSON parsing. When enabled it should improve
# performance if data is fetched from the database in a JSON format, and is
# consumed via a JSON encoder.
#
# This seems a bit far-fetched, but that use case is actually quite common
# when implementing a JSON API.
class Simple::SQL::JSON < BasicObject
  # enable lazy JSON decoding
  def self.lazy!
    @lazy = true
  end

  def self.lazy?
    !!@lazy
  end

  def self.parse(str)
    if lazy?
      new(str)
    else
      ::JSON.parse(str)
    end
  end

  def initialize(json_string)
    @json_string = json_string
  end

  def method_missing(sym, *args, &block)
    parsed.send(sym, *args, &block) || super
  end

  def respond_to_missing?(name, include_private = false)
    parsed.send(:respond_to_missing?, name, include_private) || super
  end

  def parsed
    @parsed ||= ::JSON.parse(@json_string)
  end

  def ==(other)
    super || (parsed == other)
  end

  def to_json(*_args)
    @json_string
  end
end
