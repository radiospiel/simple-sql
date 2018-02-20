require "spec_helper"

describe "Simple::SQL.duplicate" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  let!(:source_ids) { SQL.all("SELECT id FROM users") }

  before do
    SQL.ask "UPDATE users SET created_at=created_at - interval '1 hour', updated_at=updated_at - interval '1 hour'"
  end

  it "does not fail on a non-existing user" do
    dupe_ids = SQL.duplicate "users", -1

    expect(dupe_ids.length).to eq(0)
    expect(SQL.ask("SELECT COUNT(*) FROM users")).to eq(USER_COUNT)
  end

  it "duplicates a single user" do
    dupe_ids = SQL.duplicate "users", source_ids.first

    expect(dupe_ids.length).to eq(1)
    expect(SQL.ask("SELECT COUNT(*) FROM users")).to eq(1 + USER_COUNT)
  end

  it "duplicates many users" do
    dupe_ids = SQL.duplicate "users", (source_ids + [ -10 ])

    expect(dupe_ids.length).to eq(2)
    expect(SQL.ask("SELECT COUNT(*) FROM users")).to eq(2 + USER_COUNT)
  end

  it "updates the timestamp columns" do
    source_id = source_ids.first
    dupe_ids = SQL.duplicate "users", source_ids.first
    dupe_id = dupe_ids.first

    source_timestamp = SQL.ask("SELECT updated_at FROM users WHERE id=$1", source_id)
    dupe_timestamp = SQL.ask("SELECT updated_at FROM users WHERE id=$1", dupe_id)

    expect(dupe_timestamp).to be > source_timestamp
  end
end

