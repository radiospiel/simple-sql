require_relative "store_spec_helper"

describe "Simple::Store.create!" do
  include StoreSpecHelper

  shared_examples 'basic creation contract' do
    it 'assigns an id' do
      expect(record.id).to be_a(Integer)
    end

    it 'assigns a metamodel' do
      expect(record.metamodel.name).to eq(type_name)
    end

    it "does not defines a meta_data gette" do
      expect(record.respond_to?(:meta_data)).to eq(false)
    end

    it "sets timestamps" do
      now = Time.now

      expect(record.created_at).to be_within(0.01).of(now) if record.respond_to?(:created_at)
      expect(record.updated_at).to be_within(0.01).of(now) if record.respond_to?(:updated_at)
    end
  end

  context "in a simple table" do
    let!(:type_name) { "Organization" }

    let!(:record) do
      Simple::Store.create! "Organization", name: "orgname"
    end

    it_behaves_like 'basic creation contract'

    it "returns a record" do
      expected = {
        id: 1, type: "Organization", name: "orgname", city: nil
      }
      expect(record).to eq(expected)
    end

    it "creates an entry in the database" do
      expect(SQL.ask("SELECT count(*) FROM simple_store.organizations")).to eq(1)
      actual = SQL.ask("SELECT * FROM simple_store.organizations", into: Hash)
      expect(actual).to eq({ id: 1, name: "orgname", city: nil })
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

  context "in a dynamic table" do
    let!(:type_name) { "User" }

    it_behaves_like 'basic creation contract'
    
    let!(:record) do
      Simple::Store.create! "User", first_name: "first"
    end

    it "returns a record" do
      expect(record.organization_id).to eq(nil)
      expect(record.role_id).to eq(nil)
      expect(record.first_name).to eq("first")
      expect(record.last_name).to eq(nil)
      expect(record.access_level).to eq(nil)
    end

    it "creates an entry in the database" do
      expect(SQL.ask("SELECT count(*) FROM simple_store.users")).to eq(1)
      actual = SQL.ask("SELECT * FROM simple_store.users", into: Hash)
      expected = {
        id: 1,
        organization_id: nil,
        role_id: nil,
        first_name: "first",
        last_name: nil, 
        meta_data: nil,
        access_level: nil,
        type: "User"
      }
      expect(actual).to include(expected)
    end
    
    context "with unknown arguments" do
      let!(:record) do
        Simple::Store.create! "Organization", name: "orgname", foo: "Bar"
      end

      it "ignores unknown attributes" do
        expected = {
          id: 1, type: "Organization", name: "orgname", city: nil
        }
        expect(record).to eq(expected)
      end
    end
  end

  describe "argument validation" do
    shared_examples 'a validation error' do
      it 'raises an ArgumentError' do
        expect {
          ::Simple::Store.create! *params
        }.to raise_error { |e| 
          expect(e).to be_a(ArgumentError)
        }
      end
    end

    context "when a 'type' attribute is passed in" do
      it_behaves_like 'a validation error' do
        let(:params) { [ "Organization", type: "Foo" ] }
      end
    end

    context "when a 'id' attribute is passed in" do
      it_behaves_like 'a validation error' do
        let(:params) { [ "Organization", id: 12 ] }
      end
    end
  end

  describe "when passing in an array" do
    it "it builds multiple models" do
      params = [
        { name: "Foo" },
        { name: "Bar" }
      ]
      
      organizations = ::Simple::Store.create! "Organization", params
      expect(::Simple::SQL.ask "SELECT count(*) FROM simple_store.organizations").to eq(2)
      expect(organizations.map(&:name)).to eq(["Foo", "Bar" ])
    end

    it "it either builds all or none" do
      params = [
        { name: "Foo" },
        { name: nil },
        { name: "Foo2" }
      ]
      
      organizations = nil
      expect {
        organizations = ::Simple::Store.create! "Organization", params
      }.to raise_error { |e|
        expect(e).to be_a(PG::NotNullViolation)
      }
      expect(::Simple::SQL.ask "SELECT count(*) FROM simple_store.organizations").to eq(0)
    end
  end
end
