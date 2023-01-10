require "spec_helper"

describe "Connections" do
  describe "Simple::SQL.connect" do
    before do
      org = create(:organization)
      2.times { create(:user, organization_id: org.id) }
    end

    after do
      expect(User.count).to eq(2)
    end

    describe 'automatic connections' do
      let(:db) { Simple::SQL.connect }

      it 'can mix Simple::SQL inside ActiveRecord' do
        User.transaction do
          User.delete_all
          expect(db.ask("SELECT count(*) FROM users")).to eq(0)

          raise ActiveRecord::Rollback
        end

        db.transaction do
          db.ask("DELETE FROM users")

          expect(User.count).to eq(0)

          raise ActiveRecord::Rollback
        end
      end
    end

    describe 'explizit connections' do
      let(:db) { Simple::SQL.connect(Simple::SQL::Config.determine_url) }

      it 'runs in separate transactions' do
        User.transaction do
          User.delete_all
          expect(db.ask("SELECT count(*) FROM users")).to eq(2)

          raise ActiveRecord::Rollback
        end

        db.transaction do
          db.ask("DELETE FROM users")

          expect(User.count).to eq(2)

          raise ActiveRecord::Rollback
        end
      end
    end
  end

  describe "Simple::SQL.disconnect!" do
    let(:default_db) { Simple::SQL.connect }
    let(:db) { Simple::SQL.connect(Simple::SQL::Config.determine_url) }

    it 'disconnects everything' do
      Simple::SQL.disconnect!
      expect(ActiveRecord::Base.connection_pool.connections.length).to eq(0)
    end
  end
end
