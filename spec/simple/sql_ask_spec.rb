require "spec_helper"

describe "Simple::SQL.ask" do
  USER_COUNT = 2

  def expects(expected_result, sql, *args)
    expect(SQL.ask(sql, *args)).to eq(expected_result)
  end

  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "calls the database" do
    expect(User.count).to eq(2)

    expects 2, "SELECT COUNT(*) FROM users"
    expects 1, "SELECT COUNT(*) FROM users WHERE id=$1", users.first.id
    expects 0, "SELECT COUNT(*) FROM users WHERE id=$1", -1
    expects nil, "SELECT id FROM users WHERE FALSE"
  end
end
