require "spec_helper"

describe "Simple::SQL::Connection::Scope#count" do
  let!(:users)      { 1.upto(USER_COUNT).map { create(:user) } }
  let(:min_user_id) { SQL.ask "SELECT min(id) FROM users" }
  let(:scope)       { SQL.scope("SELECT * FROM users") }

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
      expect(scope.count_estimate).to eq(USER_COUNT)
    end

    it "evaluates conditions" do
      expect(scope.where("id < $1", min_user_id).count_estimate).to eq(0)
      expect(scope.where("id <= $1", min_user_id).count_estimate).to eq(1)
    end
  end
end
