require "spec_helper"

describe "Simple::SQL.record" do
  USER_COUNT = 2

  def expects(expected_result, sql, *args)
    expect(Simple::SQL.record(sql, *args)).to eq(expected_result)
  end

  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "calls the database" do
    r = Simple::SQL.record("SELECT COUNT(*) AS count FROM users")
    expect(r).to eq({count: 2}) 
  end

  it "supports the into: option" do
    r = Simple::SQL.record("SELECT COUNT(*) AS count FROM users", into: OpenStruct)
    expect(r).to be_a(OpenStruct)
    expect(r).to eq(OpenStruct.new(count: 2))
  end

  it "supports the into: option even with parameters" do
    r = Simple::SQL.record("SELECT $1::integer AS count FROM users", 2, into: OpenStruct)
    expect(r).to be_a(OpenStruct)
    expect(r).to eq(OpenStruct.new(count: 2))
  end
end
