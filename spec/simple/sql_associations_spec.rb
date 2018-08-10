require "spec_helper"

module ArrayPluck
  refine Array do
    def pluck(key)
      map { |e| e.fetch(key) }
    end
  end
end

using ArrayPluck

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

  describe ":as option" do
    it "renames a belongs_to association" do
      users = SQL.all "SELECT * FROM users WHERE organization_id=$1", org1.id, into: Hash
      users.preload :organization, as: :org

      expect(users.first.keys).not_to include(:organization)
      expect(users.first[:org]).to eq(org1.to_h)
    end

    it "renames a has_many association" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users, as: :members

      expect(organizations.first.keys).not_to include(:users)
      expect(organizations.first[:members]).to eq(users1.map(&:to_h))
    end

    it "detects a has_one association" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :user, as: :usr
      expect(organizations.first.keys).not_to include(:user)
  
      organization = organizations.first
      users_of_organization = SQL.all "SELECT * FROM users WHERE organization_id=$1", organization[:id], into: Hash
      expect(users_of_organization).to include(organization[:usr])
    end
  end

  describe ":order_by" do
    it "supports order_by" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users, order_by: "id"
      users = organizations.first[:users]

      ordered_user_ids = SQL.all("SELECT id FROM users WHERE organization_id=$1 ORDER BY id", organizations.first[:id])
      expect(users.pluck(:id)).to eq(ordered_user_ids)
    end
    
    it "supports order_by DESC" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users, order_by: "id DESC"
      users = organizations.first[:users] 

      ordered_user_ids = SQL.all("SELECT id FROM users WHERE organization_id=$1 ORDER BY id", organizations.first[:id])
      expect(users.pluck(:id)).to eq(ordered_user_ids.reverse)
    end
  end

  describe ":limit" do
    xit "limits the number of returned records" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users, limit: 1

      expect(organizations.first[:users].length).to eq(1)
    end

    xit "limits the number of returned records" do
      organizations = SQL.all "SELECT * FROM organizations", into: Hash
      organizations.preload :users, limit: 2, order_by: "id"
      users = organizations.first[:users]
      expect(users.length).to eq(2)

      ordered_user_ids = SQL.all("SELECT id FROM users WHERE organization_id=$1 ORDER BY id", organizations.first[:id])
      expect(users.pluck(:id)).to eq(ordered_user_ids)
    end
  end
end
