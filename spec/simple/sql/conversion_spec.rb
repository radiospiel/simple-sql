require "spec_helper"

describe "Simple::SQL conversions" do
  def expects(expected_result, sql, *args)
    expect(SQL.ask(sql, *args)).to eq(expected_result)
  end

  describe "data conversions" do
    it "returns arrays when asking for multiple columns" do
      expects ["one", "two", 3.5], "SELECT 'one', 'two', 3.5"
    end

    it "converts text arrays" do
      expects ["foo,bar"], "SELECT ARRAY[$1::varchar]", "foo,bar"
      expects %w(foo bar), "SELECT $1::varchar[]", %w(foo bar)
    end

    it "converts integer arrays" do
      expects [1, 2, 3], "SELECT ARRAY[1,2,3]"
    end

    it "converts weird strings properly" do
      expects "foo,\"bar}", "SELECT $1::varchar", "foo,\"bar}"
      expects ["one", "two", "3.5", "foo,\"bar}"], "SELECT ARRAY['one', 'two', '3.5', 'foo,\"bar}']"
      expects ["foo", "foo,bar}"], "SELECT $1::varchar[]", ["foo", "foo,bar}"]
      expects "foo'bar", 'SELECT $1', "foo'bar"
    end

    it "parses JSON as expected" do
      expects({ "a" => 1, "b" => 2 }, 'SELECT \'{"a":1,"b":2}\'::json')
      expects({ "a" => 1, "b" => 2 }, 'SELECT \'{"a":1,"b":2}\'::jsonb')
    end

    it "converts double precision" do
      expects 1.0, "SELECT 1.0::double precision"
    end

    it "converts bool" do
      expects true, "SELECT TRUE"
      expects false, "SELECT FALSE"
    end

    it "converts hstore" do
      expects({ a: "1", b: "3" }, "SELECT 'a=>1,b=>3'::hstore")
    end
  end

  describe "arra conversions" do
    it "works with strings" do
      expects  %w[foo bar], 'SELECT $1::varchar[]', %w[foo bar]

      # test escaping
      expects  ["foo", "foo'bar\"baz"], 'SELECT $1::varchar[]', ["foo", "foo'bar\"baz"]
      expects  [], 'SELECT $1::varchar[]', []
    end
  end
end
