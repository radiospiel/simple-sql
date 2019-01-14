require_relative "store_spec_helper"

describe "Simple::Store::Storage" do
  include StoreSpecHelper

  before do 
    Simple::Store.create! "User", first_name: "first1"
  end

  describe "loading fro database" do
    it "loads an object" do
      now = Time.now

      record = Simple::Store.ask "SELECT * FROM simple_store.users LIMIT 1"
      expect(record.id).to eq(1)
      expect(record.type).to eq("User")
      expect(record.created_at).to be_within(0.01).of(now)
      expect(record.updated_at).to be_within(0.01).of(now)
      expect(record.first_name).to eq("first1")
    end
  end
end
