require "spec_helper"

describe "Simple::SQL::Connection::Scope#count_by" do
  let!(:users)        { 1.upto(10).map { |i| create(:user, role_id: i) } }
  let(:all_role_ids)  { SQL.all("SELECT DISTINCT role_id FROM users") }
  let(:scope)         { SQL.scope("SELECT * FROM users") }

  describe "enumerate_groups" do
    it "returns all groups" do
      expect(scope.enumerate_groups("role_id")).to contain_exactly(*all_role_ids)
      expect(scope.where("role_id < 4").enumerate_groups("role_id")).to contain_exactly(*(1.upto(3).to_a))
    end
  end

  describe "count_by" do
    it "counts all groups" do
      create(:user, role_id: 1)
      create(:user, role_id: 1)
      create(:user, role_id: 1)

      expect(scope.count_by("role_id")).to include(1 => 4)
      expect(scope.count_by("role_id")).to include(2 => 1)
      expect(scope.count_by("role_id").keys).to contain_exactly(*all_role_ids)
    end
  end

  describe "fast_count_by" do
    before do
      # 10_000 is chosen "magically". It is large enough to switch to the fast algorithm,
      # but 
      allow(::Simple::SQL).to receive(:costs).and_return([0, 10_000])
    end
    
    it "counts all groups" do
      create(:user, role_id: 1)
      create(:user, role_id: 1)
      create(:user, role_id: 1)

      expect(scope.fast_count_by("role_id")).to include(1 => 4)
      expect(scope.fast_count_by("role_id")).to include(2 => 1)
      expect(scope.fast_count_by("role_id").keys).to contain_exactly(*all_role_ids)
    end
  end
end
