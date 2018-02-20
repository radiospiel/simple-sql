require "spec_helper"

describe "Simple::SQL::Reflection" do
  describe ".columns" do
    it "returns the columns of a table in the public schema" do
      expect(SQL::Reflection.columns("users")).to include("first_name")
    end

    it "returns the columns of a table in a non-'public' schema" do
      expect(SQL::Reflection.columns("information_schema.tables")).to include("table_name")
    end
  end

  describe ".tables" do
    it "returns the tables in the public schema" do
      expect(SQL::Reflection.tables).to include("users")
    end

    it "returns tables in a non-'public' schema" do
      expect(SQL::Reflection.tables(schema: "information_schema")).to include("information_schema.tables")
    end
  end
end
