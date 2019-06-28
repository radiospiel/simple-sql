require "spec_helper"

describe "Simple::SQL.connect" do
  let!(:default_pg_backend_pid) { Simple::SQL.ask "SELECT pg_backend_pid()" }

  def connection_count(db: nil)
    db ||= ::Simple::SQL
    db.ask("SELECT sum(numbackends) FROM pg_stat_database")
  end
  
  context 'without an argument' do
    let(:params) { [] }

    it 'is reusing the existing ActiveRecord connection' do
      Simple::SQL.with_connection(*params) do |db|
        expect(default_pg_backend_pid).to eq(db.ask("SELECT pg_backend_pid()"))
        expect(db).not_to be_a(Simple::SQL::Connection::ExplicitConnection)
      end

      expect(::Simple::SQL.ask("SELECT sum(numbackends) FROM pg_stat_database")).to eq(1)
    end

    it 'is not estabishing a new connection' do
      initial_connection_count = connection_count

      Simple::SQL.with_connection(*params) do |db|
        db.ask("SELECT 1")
        expect(connection_count).to eq(initial_connection_count)
      end

      expect(connection_count).to eq(initial_connection_count)
    end
  end

  context 'with an :auto argument' do
    let(:params) { [:auto] }

    it 'is reusing the existing ActiveRecord connection' do
      Simple::SQL.with_connection(*params) do |db|
        expect(default_pg_backend_pid).to eq(db.ask("SELECT pg_backend_pid()"))
        expect(db).not_to be_a(Simple::SQL::Connection::ExplicitConnection)
      end
    end

    it 'is not estabishing a new connection' do
      initial_connection_count = connection_count

      Simple::SQL.with_connection(*params) do |db|
        db.ask("SELECT 1")
        expect(connection_count).to eq(initial_connection_count)
      end

      expect(connection_count).to eq(initial_connection_count)
    end
  end

  context 'with an explicit URL' do
    let(:params) { [Simple::SQL::Config.determine_url] }

    it 'is reconnecting using the passed in URL' do
      Simple::SQL.with_connection(*params) do |db|
        expect(default_pg_backend_pid).not_to eq(db.ask("SELECT pg_backend_pid()"))
        expect(db).to be_a(Simple::SQL::Connection::ExplicitConnection)
      end
    end

    it 'is estabishing a new connection' do
      initial_connection_count = connection_count

      Simple::SQL.with_connection(*params) do |db|
        db.ask("SELECT 1")
        expect(connection_count).to be > initial_connection_count
      end

      expect(connection_count).to eq(initial_connection_count)
    end
  end
end
