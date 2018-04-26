require "spec_helper"

describe "Simple::SQL::Scope" do
  def expects(expected_result, sql, *args)
    expect(SQL.ask(sql, *args)).to eq(expected_result)
  end

  let!(:users) { 1.upto(2).map { create(:user) } }

  context "without conditions" do
    let(:scope) { SQL::Scope.new "SELECT 1, 2 FROM users" }

    it "runs with SQL.ask" do
      expect(SQL.ask(scope)).to eq([1, 2])
    end

    it "runs with SQL.all" do
      expect(SQL.all(scope)).to eq([[1, 2], [1, 2]])
    end
  end

  context "with non-argument conditions" do
    context "that do not match" do
      let(:scope) do
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
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
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
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
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
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
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
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
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
        scope = scope.where("first_name LIKE ?", "First%")
        scope.where("id < ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end
    end

    context "where second condition matches" do
      let(:scope) do
        scope = SQL::Scope.new "SELECT 1, 2 FROM users"
        scope = scope.where("first_name LIKE ?", "Boo%")
        scope.where("id >= ?", 0)
      end

      it "runs with SQL.ask" do
        expect(SQL.ask(scope)).to be_nil
      end
    end
  end

  context "describe pagination" do
    let(:scope) do
      scope = SQL::Scope.new "SELECT 1, 2 FROM users"
      scope = scope.where("first_name LIKE ?", "First%")
      scope.where("id > ?", 0)
    end

    it "sets paginated?" do
      scope.paginate(per: 1, page: 1)
      expect(scope.paginated?).to eq(true)
    end

    context "with per=1" do
      before do
        scope.paginate(per: 1, page: 1)
      end

      it "adds pagination info to the .all return value" do
        result = SQL.all(scope)

        expect(result).to eq([[1, 2]])
        expect(result.total_pages).to eq(2)
        expect(result.current_page).to eq(1)
        expect(result.total_count).to eq(2)
      end
    end

    context "with per=2" do
      before do
        scope.paginate(per: 2, page: 1)
        result = SQL.all(scope)
      end

      it "returns an empty array after the last page" do
        scope.paginate(per: 2, page: 2)
        result = SQL.all(scope)

        expect(result).to eq([])
        expect(result.total_pages).to eq(1)
        expect(result.current_page).to eq(2)
        expect(result.total_count).to eq(2)
      end

      it "adds pagination info to the .all return value" do
        result = SQL.all(scope)

        expect(result).to eq([[1, 2], [1, 2]])
        expect(result.total_pages).to eq(1)
        expect(result.current_page).to eq(1)
        expect(result.total_count).to eq(2)
      end
    end
  end
end
