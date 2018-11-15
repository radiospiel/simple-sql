require_relative "store_spec_helper"

describe "Simple::Store::Metamodel" do
  include StoreSpecHelper

  before :all do
    Simple::SQL.exec <<~SQL
      CREATE TABLE IF NOT EXISTS simple_store.simple_types (
        id SERIAL PRIMARY KEY,
        name VARCHAR
      );
    SQL
    Simple::SQL.ask <<~SQL
      CREATE TABLE IF NOT EXISTS simple_store.dynamic_types (
        id SERIAL PRIMARY KEY,
        type VARCHAR,
        organization_id INTEGER REFERENCES simple_store.organizations (id),
        role_id INTEGER,
        first_name VARCHAR,
        last_name VARCHAR,
        metadata JSONB,
        access_level access_level,
        created_at timestamp,
        updated_at timestamp
      );
      SQL
  end

  describe "Types with only static attributes" do

    let!(:metamodel) { Simple::Store::Metamodel.new(name: "Simple", table_name: "simple_store.simple_types") }

    it "uses the passed in name" do
      expect(metamodel.name).to eq("Simple")
    end

    it "sets the table_name" do
      expect(metamodel.table_name).to eq("simple_store.simple_types")
    end

    it "returns the correct set of attributes" do
      expect(metamodel.attributes).to eq(
        "id"    => { type: :integer, writable: false, readable: true, kind: :static },
        "name"  => { type: :text, writable: true, readable: true, kind: :static }
      )
    end
  end

  describe "Types with dynamic attributes" do
    let!(:metamodel) { Simple::Store::Metamodel.new(table_name: "simple_store.dynamic_types") }

    it "excludes the metadata column" do
      expect(metamodel.attributes.key?("metadata")).to eq(false)
    end

    it "automatically determines the name" do
      expect(metamodel.name).to eq("DynamicType")
    end

    it "sets the table_name" do
      expect(metamodel.table_name).to eq("simple_store.dynamic_types")
    end

    it "returns the correct set of attributes" do
      expected_attributes = {
        "id"              => { type: :integer, writable: false, readable: true, kind: :static },
        "type"            => { type: :text, writable: false, readable: true, kind: :static },
        "access_level"    => { type: :string, writable: true, readable: true, kind: :static },
        "organization_id" => { type: :integer, writable: true, readable: true, kind: :static },
        "role_id"         => { type: :integer, writable: true, readable: true, kind: :static },
        "first_name"      => { type: :text, writable: true, readable: true, kind: :static },
        "last_name"       => { type: :text, writable: true, readable: true, kind: :static },
        "created_at"      => { type: :timestamp, writable: false, readable: true, kind: :static },
        "updated_at"      => { type: :timestamp, writable: false, readable: true, kind: :static }
      }

      expect(metamodel.attributes).to eq(expected_attributes)
    end
  end
end
