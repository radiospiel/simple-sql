require "spec_helper"

describe "Simple::SQL.ask into: argument" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "calls the database" do
    r = SQL.ask("SELECT COUNT(*) AS count FROM users", into: Hash)
    expect(r).to eq({count: 2}) 
  end

  it "returns nil when there is no match" do
    r = SQL.ask("SELECT * FROM users WHERE FALSE", into: Hash)
    expect(r).to be_nil
  end

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
