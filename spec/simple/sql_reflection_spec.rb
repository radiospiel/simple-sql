require "spec_helper"

describe "Simple::SQL::Reflection" do
  describe ".columns" do
    it "returns the columns of a table in the public schema" do
      r = SQL::Reflection.columns("users")
      expect(r).to be_a(Hash)
      expect(r["first_name"].name).to eq("first_name")
    end

    it "returns the columns of a table in a non-'public' schema" do
      r = SQL::Reflection.columns("information_schema.tables")
      expect(r["table_name"].name).to eq("table_name")
    end
  end

  describe ".tables" do
    it "returns the tables in the public schema" do
      r = SQL::Reflection.tables
      expect(r.keys).to include("users")
      expect(r["users"].name).to eq("users")
    end

    it "returns tables in a non-'public' schema" do
      r = SQL::Reflection.tables(schema: "information_schema")
      expect(r.keys).to include("information_schema.tables")
      expect(r["information_schema.tables"].name).to eq("information_schema.tables")
      expect(r["information_schema.tables"].table_name).to eq("tables")
    end
  end
end
