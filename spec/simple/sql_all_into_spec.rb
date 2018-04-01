require "spec_helper"

describe "Simple::SQL.all into: argument" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "calls the database" do
    r = SQL.all("SELECT * FROM users", into: Hash)
    expect(r).to be_a(Array)
    expect(r.length).to eq(USER_COUNT)
    expect(r.map(&:class).uniq).to eq([Hash])
  end

  it "returns an empty array when there is no match" do
    r = SQL.all("SELECT * FROM users WHERE FALSE", into: Hash)
    expect(r).to eq([])
  end
end
