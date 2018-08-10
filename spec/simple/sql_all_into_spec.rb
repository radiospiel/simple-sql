require "spec_helper"

describe "Simple::SQL.ask into: :struct" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  describe "all into: X" do
    it "calls the database" do
      r = SQL.all("SELECT id FROM users", into: Hash)
      expect(r).to be_a(Array)
      expect(r.length).to eq(USER_COUNT)
      expect(r.map(&:class).uniq).to eq([Hash])
    end

    it "returns an empty array when there is no match" do
      r = SQL.all("SELECT * FROM users WHERE FALSE", into: Hash)
      expect(r).to eq([])
    end

    it "yields the results into a block" do
      received = []
      SQL.all("SELECT id FROM users", into: Hash) do |hsh|
        received << hsh
      end
      expect(received.length).to eq(USER_COUNT)
      expect(received.map(&:class).uniq).to eq([Hash])
    end

    it "does not yield if there is no match" do
      received = []
      SQL.all("SELECT id FROM users WHERE FALSE", into: Hash) do |hsh|
        received << hsh
      end
      expect(received.length).to eq(0)
    end
  end

  describe "into: :struct" do
    it "calls the database" do
      r = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
      expect(r.count).to eq(2)
      expect(r.class.members).to eq([:count])
    end

    it "reuses the struct Class" do
      r1 = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
      r2 = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
      expect(r1.class.object_id).to eq(r2.class.object_id)
    end
  end
  
  describe "into: Hash" do
    it "calls the database" do
      r = SQL.ask("SELECT COUNT(*) AS count FROM users", into: Hash)
      expect(r).to eq({count: 2}) 
    end

    it "returns nil when there is no match" do
      r = SQL.ask("SELECT * FROM users WHERE FALSE", into: Hash)
      expect(r).to be_nil
    end
  end
  
  describe "into: OpenStruct" do
    it "returns a OpenStruct with into: OpenStruct" do
      r = SQL.ask("SELECT COUNT(*) AS count FROM users", into: OpenStruct)
      expect(r).to be_a(OpenStruct)
      expect(r).to eq(OpenStruct.new(count: 2))
    end

    it "supports the into: option even with parameters" do
      r = SQL.ask("SELECT $1::integer AS count FROM users", 2, into: OpenStruct)
      expect(r).to be_a(OpenStruct)
      expect(r).to eq(OpenStruct.new(count: 2))
    end
  end
end
