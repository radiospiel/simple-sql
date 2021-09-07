require "spec_helper"

describe "Simple::SQL::Connection::Scope" do
  def expects(expected_result, sql, *args)
    expect(SQL.ask(sql, *args)).to eq(expected_result)
  end

  let!(:users) do
    1.upto(2).map { |id| create(:user, id: id) }
  end

  it 'allows chaining of scopes' do
    scope1 = SQL.scope "SELECT 1, 2 FROM users"
    scope2 = scope1.where("FALSE")
    expect(scope1.to_sql).not_to eq(scope2.to_sql)
  end

  context "without conditions" do
    let(:scope) { SQL.scope "SELECT 1, 2 FROM users" }

    it "runs with SQL.ask" do
      expect(SQL.ask(scope)).to eq([1, 2])
    end

    it "runs with SQL.all" do
      expect(SQL.all(scope)).to eq([[1, 2], [1, 2]])
    end
  end

  context "with hash conditions" do
    let(:user_id) { SQL.ask "SELECT id FROM users LIMIT 1" }
    let(:scope)   { SQL.scope "SELECT 1 FROM users" }

    context "that do not match" do
      it "does not match with string keys" do
        expect(SQL.ask(scope.where(id: -1))).to be_nil
      end

      it "does not match with symbol keys" do
        expect(SQL.ask(scope.where("id" => -1))).to be_nil
      end
    end

    context "that match" do
      it "matches with string keys" do
        expect(SQL.ask(scope.where("id" => user_id))).to eq(1)
      end

      it "matches with symbol keys" do
        expect(SQL.ask(scope.where(id: user_id))).to eq(1)
      end
    end

    context "with array arguments" do
      it "matches against array arguments" do
        expect(SQL.ask(scope.where("id" => [-333, user_id]))).to eq(1)
        expect(SQL.ask(scope.where("id" => [-333, -1]))).to be_nil
        expect(SQL.ask(scope.where("id" => []))).to be_nil
      end
    end

    context "with invalid arguments" do
      it "raises an ArgumentError" do
        expect {
          scope.where(1 => 3)
        }.to raise_error(ArgumentError)
      end
    end
  end

  context "with non-argument conditions" do
    context "that do not match" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("id < 0")
        scope.where("TRUE")
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end

      it "runs with SQL.all" do
        expect(SQL.all(scope)).to eq([])
      end
    end

    context "that do match" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("id >= 0")
        scope.where("TRUE")
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to eq([1, 2])
      end

      it "runs with SQL.all" do
        expect(SQL.all(scope)).to eq([[1, 2], [1, 2]])
      end
    end
  end

  context "with argument conditions" do
    context "that do not match" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("first_name NOT LIKE ?", "First%")
        scope.where("id < ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end

      it "runs with SQL.all" do
        expect(SQL.all(scope)).to eq([])
      end
    end

    context "where both match" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("first_name LIKE ?", "First%")
        scope.where("id >= ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to eq([1,2])
      end

      it "runs with SQL.all" do
        expect(SQL.all(scope)).to eq([[1,2], [1,2]])
      end
    end

    context "where first condition matches" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("first_name LIKE ?", "First%")
        scope.where("id < ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end
    end

    context "where second condition matches" do
      let(:scope) do
        scope = SQL.scope "SELECT 1, 2 FROM users"
        scope = scope.where("first_name LIKE ?", "Boo%")
        scope.where("id >= ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end
    end

    describe "hash matches" do
      let(:scope) { SQL.scope("SELECT id FROM users") }

      it 'validates hash keys' do
        expect {
          scope.where("foo bar" => "baz")
        }.to raise_error(ArgumentError)
      end
    end

    describe "JSONB matches" do
      before do
        SQL.exec <<~SQL
          UPDATE users SET metadata = '{"type": "user"}';
          UPDATE users SET metadata = jsonb_set(metadata, '{uid}', to_json(id)::jsonb);
        SQL
      end

      def ids_matching(condition)
        scope = SQL.scope("SELECT id FROM users")
        scope = scope.where(condition)
        SQL.all(scope)
      end

      it "runs with SQL.ask" do
        # exact match
        expect(ids_matching(metadata: { "uid" => 1 })).to contain_exactly(1)

        # match against array
        expect(ids_matching(metadata: { "uid" => [] })).to contain_exactly()
        expect(ids_matching(metadata: { "uid" => [1, -1] })).to contain_exactly(1)
        expect(ids_matching(metadata: { "uid" => [1, 2] })).to contain_exactly(1, 2)

        # match against array of mixed types
        expect(ids_matching(metadata: { "uid" => [1, "-1"] })).to contain_exactly(1)

        # match against multiple conditions
        expect(ids_matching(metadata: { "uid" => [1, "-1"], "type" => "foo" })).to contain_exactly()
        expect(ids_matching(metadata: { "uid" => [1, "-1"], "type" => ["foo", "user"] })).to contain_exactly(1)
        expect(ids_matching(metadata: { "uid" => [1, "-1"], "type" => [] })).to contain_exactly()
      end
    end
  end

  context "Building with Hash" do
    it "runs with SQL.ask" do
      scope = SQL.scope table: "users", select: "1, 2", where: "id >= 0"
      expect(SQL.all(scope)).to eq([[1,2], [1,2]])

      scope = SQL.scope table: "users", select: [1,3,4], where: "id >= 0"
      expect(SQL.all(scope)).to eq([[1,3,4], [1,3,4]])
    end
    
    it "raises an error with missing or invalid attributes" do
      expect { SQL.scope table: "users", limit: 1 }.to raise_error(ArgumentError)
      expect { SQL.scope select: "*" }.to raise_error(ArgumentError)
    end
  end

  context "describe pagination" do
    let(:scope) do
      scope = SQL.scope "SELECT 1, 2 FROM users"
      scope = scope.where("first_name LIKE ?", "First%")
      scope.where("id > ?", 0)
    end

    it "sets paginated?" do
      s = scope.paginate(per: 1, page: 1)
      expect(s.paginated?).to eq(true)
    end

    context "with per=1" do
      it "adds pagination info to the .all return value" do
        result = SQL.all(scope.paginate(per: 1, page: 1))

        expect(result).to eq([[1, 2]])
        expect(result.current_page).to eq(1)
        expect(result.total_count).to eq(2)
      end
    end

    context "with per=2" do
      it "returns an empty array after the last page" do
        result = SQL.all(scope.paginate(per: 2, page: 2))

        expect(result).to eq([])
        expect(result.current_page).to eq(2)
        expect(result.total_count).to eq(2)
      end

      it "adds pagination info to the .all return value" do
        result = SQL.all(scope.paginate(per: 2, page: 1))

        expect(result).to eq([[1, 2], [1, 2]])
        expect(result.current_page).to eq(1)
        expect(result.total_count).to eq(2)
      end
    end
  end
end
