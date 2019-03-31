require "spec_helper"

describe "Simple::SQL::Result counts" do
  let!(:users)          { 1.upto(USER_COUNT).map { create(:user) } }
  let(:min_user_id)     { SQL.ask "SELECT min(id) FROM users" }
  let(:scope)           { SQL.scope("SELECT * FROM users") }
  let(:paginated_scope) { scope.paginate(per: 1, page: 1) }

  describe "exact counting" do
    it "counts" do
      result = SQL.all(paginated_scope)
      expect(result.total_count).to eq(USER_COUNT)
      expect(result.total_pages).to eq(USER_COUNT)
      expect(result.current_page).to eq(1)
    end
  end
  
  describe "fast counting" do
    it "counts fast" do
      result = SQL.all(paginated_scope)

      expect(result.total_fast_count).to eq(USER_COUNT)
      expect(result.total_fast_pages).to eq(USER_COUNT)
      expect(result.current_page).to eq(1)
    end
  end

  context 'when running with a non-paginated paginated_scope' do
    it "raises errors" do
      result = SQL.all(scope)

      expect { result.total_count }.to raise_error(RuntimeError)
      expect { result.total_pages }.to raise_error(RuntimeError)
      expect { result.current_page }.to raise_error(RuntimeError)
      expect { result.total_fast_count }.to raise_error(RuntimeError)
      expect { result.total_fast_pages }.to raise_error(RuntimeError)
    end
  end


  context 'when running with an empty, paginated paginated_scope' do
    let(:scope)           { SQL.scope("SELECT * FROM users WHERE FALSE") }
    let(:paginated_scope) { scope.paginate(per: 1, page: 1) }

    it "returns correct results" do
      result = SQL.all(paginated_scope)

      expect(result.total_count).to eq(0)
      expect(result.total_pages).to eq(1)

      expect(result.total_fast_count).to eq(0)
      expect(result.total_fast_pages).to eq(1)

      expect(result.current_page).to eq(1)
    end
  end
end
