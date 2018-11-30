require_relative "store_spec_helper"

describe "Simple::Store::Model" do
  include StoreSpecHelper

  let(:user_klass) { Simple::Store::Metamodel.resolve "Organization" }
  let(:user)       { user_klass.build({}) }

  describe "to_json" do
    it "returns a json string" do
      expect(user.to_json).to eq("{\"type\":\"Organization\",\"id\":null}")
    end

    it "returns a json string when created" do
      user = Simple::Store.create! "Organization", { name: "foo"}
      expect(user.to_json).to eq("{\"id\":1,\"name\":\"foo\",\"city\":null,\"type\":\"Organization\"}")
    end

    it "returns a json string when loaded" do
      user = Simple::Store.create! "Organization", { name: "foo"}
      loaded = Simple::Store.ask "SELECT * FROM simple_store.organizations LIMIT 1"
      expect(loaded.to_json).to eq("{\"id\":1,\"name\":\"foo\",\"city\":null,\"type\":\"Organization\"}")
    end
  end

  describe "method_missing getters" do
    it "implements getters for readable attributes" do
      expect(user.respond_to?(:name)).to eq(true)
      expect(user.name).to be_nil
    end
    
    it "raises a NoMethodError on unknown_attributes" do
      expect(user.respond_to?(:unknown_attribute)).to eq(false)
      expect { user.unknown_attribute }.to raise_error(NoMethodError)
    end
  end

  describe "method_missing setters" do
    it "implements setters for writable attributes" do
      expect(user.respond_to?(:name)).to eq(true)
      user.name = "changed"
      expect(user.name).to eq("changed")
    end

    it "raises a NoMethodError on unknown_attributes" do
      expect(user.respond_to?(:unknown_attribute=)).to eq(false)
      expect { user.unknown_attribute = 1 }.to raise_error(NoMethodError)
    end

    it "raises a NoMethodError on readonly attributes" do
      expect(user.respond_to?(:unknown_attribute=)).to eq(false)
      expect { user.unknown_attribute = 1 }.to raise_error(NoMethodError)
    end
  end

  describe "#inspect" do
    let(:saved_user)    { Simple::Store.create! "Organization", { name: "foo" } }
    let(:return_value)  { saved_user.inspect }

    it "returns a string" do
      expect(user.inspect).to       eq('<Organization#nil>')
    end

    it "contains attributes" do
      expect(user.inspect).to       eq('<Organization#nil>')
      expect(saved_user.inspect).to eq('<Organization#1: city: nil, name: "foo">')
    end
  end
end
