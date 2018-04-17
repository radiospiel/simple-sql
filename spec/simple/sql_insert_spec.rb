require "spec_helper"

describe "Simple::SQL.insert" do
  let!(:users) { 1.upto(USER_COUNT).map { create(:user) } }

  it "inserts a single user" do
    initial_ids = SQL.all("SELECT id FROM users")

    id = SQL.insert :users, first_name: "foo", last_name: "bar"
    expect(id).to be_a(Integer)
    expect(initial_ids).not_to include(id)
    expect(SQL.ask("SELECT count(*) FROM users")).to eq(USER_COUNT+1)

    user = SQL.ask("SELECT * FROM users WHERE id=$1", id, into: OpenStruct)
    expect(user.first_name).to eq("foo")
    expect(user.last_name).to eq("bar")
    expect(user.created_at).to be_a(Time)
  end

  describe 'confict handling' do
    let!(:existing_user_id) { SQL.insert :users, {first_name: "foo", last_name: "bar"} }
    let!(:total_users) { SQL.ask "SELECT count(*) FROM users" }
    
    context 'when called with on_conflict: :ignore' do
      it 'ignores the conflict and does not create a user' do
        # Try to insert using an existing primary key ...
        result = SQL.insert :users, {id: existing_user_id, first_name: "foo", last_name: "bar"}, on_conflict: :ignore
        expect(result).to be_nil

        expect(SQL.ask("SELECT count(*) FROM users")).to eq(total_users)
      end
    end
    
    context 'when called with on_conflict: :nothing' do
      it 'ignores the conflict and does not create a user' do
        # Try to insert using an existing primary key ...
        result = SQL.insert :users, {id: existing_user_id, first_name: "foo", last_name: "bar"}, on_conflict: :nothing
        expect(result).to be_nil

        expect(SQL.ask("SELECT count(*) FROM users")).to eq(total_users)
      end
    end

    context 'when called with on_conflict: nil' do
      it 'raises an error and does not create a user' do
        # Try to insert using an existing primary key ...
        expect {
          SQL.insert :users, {id: existing_user_id, first_name: "foo", last_name: "bar"}, on_conflict: nil
        }.to raise_error(PG::UniqueViolation)

        expect(SQL.ask("SELECT count(*) FROM users")).to eq(total_users)
      end
    end
  end
end
