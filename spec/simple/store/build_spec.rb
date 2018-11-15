require_relative "store_spec_helper"

describe "Simple::Store.build" do
  include StoreSpecHelper

  context "in a simple table" do
    let!(:type_name) { "Organization" }

    let!(:model) do
      Simple::Store.build "Organization", name: "orgname"
    end

    it "returns a model" do
      expected = {
        id: nil, type: "Organization", name: "orgname"
      }
      expect(model.id).to be_nil
      expect(model).to eq(expected)
    end

    it "creates no entry in the database" do
      expect(SQL.ask("SELECT count(*) FROM simple_store.organizations")).to eq(0)
    end

    context "with unknown arguments" do
      let!(:record) do
        Simple::Store.create! "Organization", name: "orgname", foo: "Bar"
      end

      it "ignores unknown attributes" do
        expected = {
          type: "Organization",
          id: 1, name: "orgname",
          city: nil
        }
        expect(record).to eq(expected)
      end
    end
  end
end
