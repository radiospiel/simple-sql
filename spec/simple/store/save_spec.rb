require_relative "store_spec_helper"

describe "Simple::Store.save!" do
  include StoreSpecHelper

  before do
    Simple::Store.create! "Organization", name: "orgname1"
    Simple::Store.create! "Organization", name: "orgname2"
    Simple::Store.create! "Organization", name: "orgname3"
  end

  context "with an unsaved model" do
    let!(:unsaved_model)  { Simple::Store.build "Organization", name: "orgname" }
    let!(:returned_model) { Simple::Store.save! unsaved_model }

    it "saves into the database" do
      reloaded = Simple::Store.ask("SELECT * FROM simple_store.organizations WHERE id=4")
      expected = {
        id: 4, type: "Organization", name: "orgname", city: nil
      }
      expect(reloaded).to eq(expected)
    end

    it "returns a saved model" do
      expected = {
        id: 4, type: "Organization", name: "orgname", city: nil
      }
      expect(returned_model).to eq(expected)
    end

    it "sets the id in the original model" do
      expect(unsaved_model.id).to eq(4)
    end
    
    it "does not touch other objects" do
      names = SQL.all "SELECT name FROM simple_store.organizations"
      expect(names).to contain_exactly("orgname1", "orgname2", "orgname3", "orgname")
    end
  end

  context "with a saved model" do
    let!(:saved_model)    { Simple::Store.create! "Organization", name: "orgname" }
    let!(:returned_model) { 
      saved_model.name = "changed"
      Simple::Store.save! saved_model 
    }

    it "saves into the database" do
      reloaded = Simple::Store.ask("SELECT * FROM simple_store.organizations WHERE id=4")
      expected = {
        id: 4, type: "Organization", name: "changed", city: nil
      }
      expect(reloaded).to eq(expected)
    end

    it "returns a saved model" do
      expected = {
        id: 4, type: "Organization", name: "changed", city: nil
      }
      expect(returned_model).to eq(expected)
    end

    it "sets the id in the original model" do
      expect(saved_model.id).to eq(4)
    end
    
    it "does not touch other objects" do
      names = SQL.all "SELECT name FROM simple_store.organizations"
      expect(names).to contain_exactly("orgname1", "orgname2", "orgname3", "changed")
    end
  end
end
