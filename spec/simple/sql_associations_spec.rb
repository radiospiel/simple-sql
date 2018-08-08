require "spec_helper"

describe "Simple::SQL::Result#preload" do
  let!(:org1)     { create(:organization) }
  let!(:users1)   { 1.upto(USER_COUNT).map { create(:user, organization_id: org1.id) } }
  let!(:org2)     { create(:organization) }
  let!(:users2)   { 1.upto(USER_COUNT).map { create(:user, organization_id: org2.id) } }
  let!(:users)    { 1.upto(USER_COUNT).map { create(:user) } }

  # The block below checks that the factories are set up correctly.
  describe "factories used in spec" do
    it "builds correct objects" do
      expect(org1.id).not_to eq(org2.id)
      expect(users1.map(&:organization_id).uniq).to eq([org1.id])
      expect(users2.map(&:organization_id).uniq).to eq([org2.id])
      expect(users.map(&:organization_id).uniq).to eq([nil])
    end
  end

  # describe "correctness" do
  #   it "resolves a belongs_to association" do
  #     users = SQL.all "SELECT * FROM users WHERE organization_id=$1", org1.id, into: Hash
  #     users.preload :organization
  #     expect(users.first[:organization]).to eq(org1.to_h)
  #   end
  #
  #   it "resolves a has_many association" do
  #     organizations = SQL.all "SELECT * FROM organizations", into: Hash
  #     organizations.preload :users
  #     expect(organizations.first[:users]).to eq(users1.map(&:to_h))
  #   end
  #
  #   it "resolves a has_one association" do
  #     organizations = SQL.all "SELECT * FROM organizations", into: Hash
  #     organizations.preload :user
  #
  #     organization = organizations.first
  #     users_of_organization = SQL.all "SELECT * FROM users WHERE organization_id=$1", organization[:id], into: Hash
  #     expect(users_of_organization).to include(organization[:user])
  #   end
  # end

  describe "automatic detection via foreign keys" do
    it "detects a belongs_to association" do
      users = SQL.all "SELECT * FROM users WHERE organization_id=$1", org1.id, into: Hash
      users.preload :organization
      expect(users.first[:organization]).to eq(org1.to_h)
    end

    it "detects a has_many association" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users
      expect(organizations.first[:users]).to eq(users1.map(&:to_h))
    end

    it "detects a has_one association" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :user
  
      organization = organizations.first
      users_of_organization = SQL.all "SELECT * FROM users WHERE organization_id=$1", organization[:id], into: Hash
      expect(users_of_organization).to include(organization[:user])
    end
  end
end
