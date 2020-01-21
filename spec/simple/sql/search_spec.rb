require "spec_helper"

describe "Simple::SQL.search" do
  let!(:users) do
    1.upto(10).map { |i| 
      metadata = { user_id_squared: i * i, id_string: "user-#{i}", even_str: i.even? ? "yes" : "no" }
      metadata[:odd] = true if i.odd?
      metadata[:always_odd] = i.odd? ? true : nil      # always_even is always set, in contrast to odd
      create(:user, role_id: i, metadata: metadata)
    } 
  end

  let(:scope) do
    scope = SQL.scope("SELECT * FROM users") 
    scope.table_name = "users"
    scope
  end

  def search(*args)
    scope.search(*args).all
  end

  it "filters by one dynamic attribute and one match" do
    expect(search(even_str: "yes").map(&:id)).to contain_exactly(2,4,6,8,10)
  end

  it "filters by one dynamic attribute and multiple matches" do
    expect(search(user_id_squared: [1, 3, 9]).map(&:id)).to contain_exactly(1,3)
  end

  it "filters by unknown dynamic attribute" do
    expect(search(no_such_str: "yes").map(&:id)).to contain_exactly()
  end

  it "converts strings to integers" do
    expect(search(user_id_squared: [1, "4", "9"]).map(&:id)).to contain_exactly(1,2,3)
  end

  it "filters by multiple dynamic attributes" do
    expect(search(user_id_squared: [1, "4", "9"], even_str: "yes").map(&:id)).to contain_exactly(2)
  end

  it "filters by multiple mixed attributes" do
    expect(search(id: [1, "2", "3", 4], even_str: "yes").map(&:id)).to contain_exactly(2, 4)
  end

  it "filters for non-existing dynamic attributes" do
    expect(search(odd: []).map(&:id)).to contain_exactly(2, 4, 6, 8, 10)
    expect(search(odd: nil).map(&:id)).to contain_exactly(2, 4, 6, 8, 10)
  end

  it "filters for non-existing dynamic attributes" do
    expect(search(always_odd: nil).map(&:id)).to contain_exactly(2, 4, 6, 8, 10)
  end
end
