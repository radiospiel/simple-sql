require "spec_helper"

describe "Simple::SQL.duplicate/unique indices" do
  let!(:unique_users) { 1.upto(USER_COUNT).map { create(:unique_user) } }

  let!(:source_ids) { SQL.all("SELECT id FROM unique_users") }

  it "cannot duplicate unique_user" do
    expect {
      SQL.duplicate "unique_users", source_ids
    }.to raise_error(PG::UniqueViolation)
  end

  it "raises an ArgumentError when called with unknown columns" do
    expect {
      SQL.duplicate "unique_users", source_ids, foo: SQL.fragment("baz")
    }.to raise_error(ArgumentError)
  end

  it "raises an ArgumentError when called with invalid overrides" do
    expect {
      SQL.duplicate "unique_users", source_ids, first_name: "I am invalid"
    }.to raise_error(ArgumentError)
  end

  it "duplicates unique_users" do
    overrides = {
      first_name:  SQL.fragment("first_name || '.' || id"),
      last_name:   SQL.fragment("last_name || '.' || id")
    }

    dupe_ids = SQL.duplicate "unique_users", source_ids, overrides

    expect(dupe_ids.length).to eq(2)
    expect(SQL.ask("SELECT COUNT(*) FROM unique_users")).to eq(4)
  end
end
