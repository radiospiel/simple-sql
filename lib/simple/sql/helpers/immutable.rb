module Simple
  module SQL
    module Helpers
    end
  end
end

class Simple::SQL::Helpers::Immutable
  SELF = self

  # turns an object, which can be a hash or array of hashes, arrays, and scalars
  # into an object which you can use to access with dot methods.
  def self.create(object, max_depth = 5)
    case object
    when Array
      raise ArgumentError, "Object nested too deep (or inner loop?)" if max_depth < 0

      object.map { |obj| create obj, max_depth - 1 }
    when Hash
      new(object)
    else
      object
    end
  end

  private

  def initialize(hsh)
    @hsh = hsh
  end

  def method_missing(sym, *args, &block)
    if args.empty? && !block
      begin
        value = @hsh.fetch(sym.to_sym) { @hsh.fetch(sym.to_s) }
        return SELF.create(value)
      rescue KeyError
        # STDERR.puts "Missing attribute #{sym} for Immutable w/#{@hsh.inspect}"
        nil
      end
    end

    super
  end

  public

  def respond_to_missing?(method_name, include_private = false)
    @hsh.key?(method_name.to_sym) ||
      @hsh.key?(method_name.to_s) ||
      super
  end

  def to_hash
    @hsh
  end

  def inspect
    "<Immutable: #{@hsh.inspect}>"
  end

  def respond_to?(sym)
    super || @hsh.key?(sym.to_s) || @hsh.key?(sym.to_sym)
  end

  def ==(other)
    @hsh == other
  end
end

if $PROGRAM_NAME == __FILE__

  # rubocop:disable Metrics/AbcSize

  require "test-unit"

  class Simple::SQL::Helpers::Immutable::TestCase < Test::Unit::TestCase
    Immutable = ::Simple::SQL::Helpers::Immutable

    def hsh
      {
        a: "a-value",
        "b": "b-value",
        "child": {
          name: "childname",
          grandchild: {
            name: "grandchildname"
          }
        },
        "children": [
          "anna",
          "arthur",
          {
            action: {
              keep_your_mouth_shut: true
            }
          }
        ]
      }
    end

    def immutable
      Immutable.create hsh
    end

    def test_hash_access
      assert_equal "a-value", immutable.a
      assert_equal "b-value", immutable.b
    end

    def test_comparison
      immutable = Immutable.create hsh

      assert_equal immutable, hsh
      assert_not_equal({}, immutable)
    end

    def test_child_access
      child = immutable.child
      assert_kind_of(Immutable, child)
      assert_equal "childname", immutable.child.name
      assert_equal "grandchildname", immutable.child.grandchild.name
    end

    def test_array_access
      assert_kind_of(Array, immutable.children)
      assert_equal 3, immutable.children.length
      assert_equal "anna", immutable.children[0]

      assert_kind_of(Immutable, immutable.children[2])
      assert_equal true, immutable.children[2].action.keep_your_mouth_shut
    end

    def test_base_class
      assert_nothing_raised do
        immutable.object_id
      end
    end

    def test_missing_keys
      assert_raise(NoMethodError) do
        immutable.foo
      end
    end

    def test_skip_when_args_or_block
      assert_raise(NoMethodError) do
        immutable.a(1, 2, 3)
      end
      assert_raise(NoMethodError) do
        immutable.a { :dummy }
      end
    end
  end

end
