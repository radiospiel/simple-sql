require_relative "store_spec_helper"

describe "Simple::Store::Metamodel.register" do
  include StoreSpecHelper

  after do
    Simple::Store::Metamodel.unregister("User2")
  end

  context "when registering based on table_name" do
    before do
      @result = Simple::Store::Metamodel.register("User2", table_name: "simple_store.users")
    end

    it "registers a metamodel" do
      metamodel = Simple::Store::Metamodel.resolve "User2"
      expect(metamodel).to be_a(Simple::Store::Metamodel)
      expect(metamodel.name).to eq("User2")
    end

    it "returns a metamodel" do
      metamodel = @result
      expect(metamodel).to be_a(Simple::Store::Metamodel)
      expect(metamodel.name).to eq("User2")
    end
  end

  context "when adjusting a registration based on table_name" do
    before do
      Simple::Store::Metamodel.register("User2", table_name: "simple_store.users") do
        attribute :last_name, writable: false
      end
    end

    it "replaces existing attribute options" do
      metamodel = Simple::Store::Metamodel.resolve "User2"
      expect(metamodel.attributes["last_name"]).to eq({:type=>:text, :writable=>false, :readable=>true, :kind=>:static})
    end
  end

  context "when adjusting a registration based on table_name" do
    before do
      Simple::Store::Metamodel.register("User2", table_name: "simple_store.users") do
        attribute :last_name, writable: false
      end
    end

    it "replaces existing attribute options" do
      metamodel = Simple::Store::Metamodel.resolve "User2"
      expect(metamodel.attributes["last_name"]).to eq({:type=>:text, :writable=>false, :readable=>true, :kind=>:static})
    end
  end
end
