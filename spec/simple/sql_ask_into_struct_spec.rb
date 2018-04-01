require "spec_helper"

describe "Simple::SQL.ask into: :struct" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "calls the database" do
    r = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
    expect(r.count).to eq(2)
    expect(r.class.members).to eq([:count])
  end

  it "reuses the struct" do
    r1 = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
    r2 = SQL.ask("SELECT COUNT(*) AS count FROM users", into: :struct)
    expect(r1.class.object_id).to eq(r2.class.object_id)
  end
end
