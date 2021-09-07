require "spec_helper"

describe "Simple::SQL::Connection::Scope#count_by" do
  let!(:users)                  { 1.upto(10).map { |i| create(:user, role_id: i) } }
  let(:scope)                   { SQL.scope("SELECT * FROM users") }

  let(:all_role_ids)            { 1.upto(10).to_a }
  let(:all_role_ids_w_squares)  { all_role_ids.map { |role_id| [role_id, role_id*role_id] } } 

  before do
    # initially we have 10 users, one per role_id in the range 1 .. 10
    # This adds another 3 users with role_id of 1.
    create(:user, role_id: 1)
    create(:user, role_id: 1)
    create(:user, role_id: 1)
  end

  describe "enumerate_groups" do
    it "returns all groups by a single column" do
      expect(scope.enumerate_groups("role_id")).to contain_exactly(*all_role_ids)
    end

    it "obeys where conditions" do
      expect(scope.where("role_id < $1", 4).enumerate_groups("role_id")).to contain_exactly(1,2,3)
    end

    it "counts all groups by multiple columns" do
      expect(scope.where("role_id < $1", 4).enumerate_groups("role_id, role_id * role_id")).to contain_exactly([1, 1], [2, 4], [3, 9])
    end
  end

  describe "count_by" do
    it "counts all groups by a single column" do
      expect(scope.count_by("role_id")).to include(1 => 4)
      expect(scope.count_by("role_id")).to include(2 => 1)
      expect(scope.count_by("role_id").keys).to contain_exactly(*all_role_ids)
    end

    it "counts all groups by multiple columns" do
      expect(scope.where("role_id < $1", 4).count_by("role_id, role_id * role_id")).to include([1,1] => 4)
      expect(scope.where("role_id < $1", 4).count_by("role_id, role_id * role_id")).to include([2, 4] => 1)
      expect(scope.where("role_id < $1", 4).count_by("role_id, role_id * role_id").keys).to contain_exactly([1, 1], [2, 4], [3, 9])
    end
  end

  describe "count_by_estimate" do
    before do
      expect_any_instance_of(Simple::SQL::Connection).to receive(:estimate_cost).at_least(:once).and_return(10_000)
    end

    it "counts all groups by a single column" do
      expect(scope.count_by_estimate("role_id")).to include(1 => 4)
      expect(scope.count_by_estimate("role_id")).to include(2 => 1)
      expect(scope.count_by_estimate("role_id").keys).to contain_exactly(*all_role_ids)
    end

    it "counts all groups by multiple columns and conditions" do
      expect(scope.where("role_id < $1", 4).count_by_estimate("role_id, role_id * role_id")).to include([1,1] => 4)
      expect(scope.where("role_id < $1", 4).count_by_estimate("role_id, role_id * role_id")).to include([2, 4] => 1)
      expect(scope.where("role_id < $1", 4).count_by_estimate("role_id, role_id * role_id").keys).to contain_exactly([1, 1], [2, 4], [3, 9])
    end
  end
end
