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

  describe "virtual attributes" do
    before do
      Simple::Store.create! "User", first_name: "foo", last_name: "bar"
    end

    let!(:user) { Simple::Store.ask "SELECT * FROM simple_store.users LIMIT 1" }

    it "calculates value when requested" do
      expect(user.full_name).to eq("foo bar")
    end

    it "includes the virtual attribute in the full_hash result", pending: "needs full_hash" do
      hsh = user.to_hash

      expect(hsh["full_name"]).to eq("foo bar")
    end

    it "does not memoize the virtual attribute in the initial record" do
      expect(user.full_name).to eq("foo bar")
      user.first_name = "baz"
      expect(user.full_name).to eq("baz bar")
    end
    
    context "with an incomplete object" do
      let!(:user) { Simple::Store.ask "SELECT id, first_name FROM simple_store.users LIMIT 1" }

      it "does not implement the getter" do
        expect {
          user.full_name
        }.to raise_error(NameError)
      end

      it "does not include the virtual attribute in the to_hash result" do
        hsh = user.to_hash

        expect(hsh["full_name"]).to be_nil
      end
    end
  end
end
