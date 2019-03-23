require "spec_helper"

describe "Simple::SQL::Scope#count" do
  let!(:users)      { 1.upto(USER_COUNT).map { create(:user) } }
  let(:min_user_id) { SQL.ask "SELECT min(id) FROM users" }
  let(:scope)       { SQL::Scope.new("SELECT * FROM users") }

  describe "exact count" do
    it "counts" do
      expect(scope.count).to eq(USER_COUNT)
    end

    it "evaluates conditions" do
      expect(scope.where("id < $1", min_user_id).count).to eq(0)
      expect(scope.where("id <= $1", min_user_id).count).to eq(1)
    end
  end

  describe "fast count" do
    it "counts" do
      expect(scope.fast_count).to eq(USER_COUNT)
    end

    it "evaluates conditions" do
      expect(scope.where("id < $1", min_user_id).fast_count).to eq(0)
      expect(scope.where("id <= $1", min_user_id).fast_count).to eq(1)
    end
  end
end
