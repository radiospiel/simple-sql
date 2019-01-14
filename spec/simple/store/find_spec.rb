require_relative "store_spec_helper"

describe "Simple::Store.find" do
  include StoreSpecHelper

  before do 
    Simple::Store.create! "User", first_name: "first1"
    Simple::Store.create! "User", first_name: "first2"
    Simple::Store.create! "User", first_name: "first3"
  end

  describe "reload(model)" do
    it "reloads an object" do
      user = Simple::Store.ask "SELECT * FROM simple_store.users LIMIT 1"

      reloaded_user = Simple::Store.reload user
      expect(reloaded_user).to eq(reloaded_user)
    end
  end

  describe "find(type, id)" do
    it "returns a record" do
      rec = Simple::Store.find "User", 1
    end

    it "raises an error if the id cannot be found" do
      expect {
        Simple::Store.find "User", -1
      }.to raise_error { |e| 
        expect_records_not_found(e, "User", [-1])
      }
    end

    it "raises an error if multiple ids cannot be found" do
      expect {
        Simple::Store.find "User", [-1, -2]
      }.to raise_error { |e| 
        expect_records_not_found(e, "User", [-1, -2])
      }
    end
  end

  describe "find(type, ids)" do
    it "returns an array of record" do
      rec = Simple::Store.find "User", [1, 2]
      expect(rec.map(&:id)).to eq([1,2])

      rec = Simple::Store.find "User", [2, 1]
      expect(rec.map(&:id)).to eq([2,1])
    end

    it "raises an error if the id cannot be found" do
      expect {
        Simple::Store.find "User", -1
      }.to raise_error { |e| 
        expect_records_not_found(e, "User", [-1])
      }
    end

    it "raises an error if multiple ids cannot be found" do
      expect {
        Simple::Store.find "User", [-1, -2]
      }.to raise_error { |e| 
        expect_records_not_found(e, "User", [-1, -2])
      }
    end
  end

  describe "find(types, ids)" do
    it "raises an error if types refer to different tables" do
      expect {
        Simple::Store.find ["User", "Organization"], [-1, -2]
      }.to raise_error { |e|
        expect(e).to be_a(ArgumentError)
        expect(e.message).to match(/Duplicate tables/)
      }
    end
  end
end
