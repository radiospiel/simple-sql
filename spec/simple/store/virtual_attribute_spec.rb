require_relative "store_spec_helper"

describe "virtual_attributes" do
  include StoreSpecHelper

  describe "registration" do
    before :all do
      Simple::Store::Metamodel.register "User3", table_name: "simple_store.users" do
        attribute :full_name, kind: :virtual
      end

      Simple::Store::Metamodel.register_virtual_attributes "User3" do
        def full_name(user)
          "#{user.first_name} #{user.last_name}"
        end
      end
    end

    after :all do
      Simple::Store::Metamodel.unregister("User3")
    end
    
    let(:metamodel) { Simple::Store::Metamodel.resolve "User3" }

    it "registers a metamodel" do
      expect(metamodel).to be_a(Simple::Store::Metamodel)
      expect(metamodel.name).to eq("User3")
    end

    it "makes the virtual attribute read only" do
      expect(metamodel.attributes["full_name"][:writable]).to eq(false)
    end
  end

  describe "reading virtual attributes" do
    let!(:user) { Simple::Store.create! "User", first_name: "foo", last_name: "bar" }

    it "calculates the virtual attribute when requested" do
      expect(user.full_name).to eq("foo bar")
    end

    it "includes the virtual attribute" do
      hsh = user.to_hash

      expect(hsh["full_name"]).to eq("foo bar")
    end

    it "does not include the virtual attribute in the initial record", pending: "[TODO] Implement lazy virtual attributes" do
      hsh = user.instance_variable_get :@to_hash

      expect(hsh["full_name"]).to be_nil
    end
  end
end
