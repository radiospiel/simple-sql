# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/LineLength

require "spec_helper"
require "simple/graph"

describe "Simple::Graph" do
  describe "query w/explicit attributes and collection parameters" do
    let(:query) do
      Simple::Graph.query("booktown.books", per: 1000, order: "author_id") do
        collection do
          order   "id asc"    # overrides the default order
          per     3           # overrides the default per
        end

        records {
          author_id
          subject_id
          id_squared "id * id" # additional attributes
        }
      end
    end

    it "resolves a query" do
      expected_records = [
        { author_id: 115,     id_squared: 24_336,    subject_id: 9 },
        { author_id: 16,      id_squared: 36_100,    subject_id: 6 },
        { author_id: 25_041,  id_squared: 1_522_756, subject_id: 3 }
      ]

      actual = Simple::Graph.resolve(query, per: 3)
      expect(actual).to include(records: expected_records)
    end
  end

  describe "internal_attributes: true" do
    let(:query) do
      Simple::Graph.query("booktown.books")
    end

    it "keeps internal_attributes" do
      expected_records = [
        { :__id__=>156, :__struct__=>"booktown.books", author_id: 115, id: 156, subject_id: 9, title: "The Tell-Tale Heart" },
        { :__id__=>190, :__struct__=>"booktown.books", author_id: 16,  id: 190, subject_id: 6, title: "Little Women" }
      ]

      actual = Simple::Graph.resolve(query, per: 2, order: "id asc", internal_attributes: true)
      expect(actual).to include(records: expected_records)
    end
  end

  describe "query w/counts" do
    let(:query) do
      Simple::Graph.query("booktown.books", per: 1000, order: "author_id") do
        counts do
          author_id
        end
      end
    end

    it "resolves a query" do
      expected_records = []
      expected_counts = {
        author_id: { 1866 => 1, 1644 => 1, 115 => 1, 4156 => 1, 2001 => 1, 1809 => 2, 7806 => 1, 1212 => 1, 2031 => 1, 25_041 => 1, 7805 => 2, 15_990 => 1, 16 => 1 }
      }

      actual = Simple::Graph.resolve(query, per: 0)

      expect(actual[:records]).to eq(expected_records)
      expect(actual[:counts]).to eq(expected_counts)
    end
  end
end
