# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/LineLength

require "spec_helper"
require "simple/graph"

describe "Simple::Graph associations" do
  describe "internal_attributes: true" do
    let(:query) do
      Simple::Graph.query("booktown.books", order: "id asc", per: 3) do
        records {
          id
          author_id
          subject_id
        }

        belongs_to :author do
          # note that this only includes limited attributes
          records {
            id
            first_name
          }
        end
      end
    end

    it "keps internal attributes" do
      expected_records = [
        { __struct__: "booktown.books", __id__: 156,  author_id: 115,     id: 156,  subject_id: 9, :author=>{__struct__: "booktown.authors", __id__: 115,   first_name: "Edgar Allen", id: 115} },
        { __struct__: "booktown.books", __id__: 190,  author_id: 16,      id: 190,  subject_id: 6, :author=>{__struct__: "booktown.authors", __id__: 16,   first_name: "Louisa May", id: 16} },
        { __struct__: "booktown.books", __id__: 1234, author_id: 25_041,  id: 1234, subject_id: 3, :author=>{__struct__: "booktown.authors", __id__: 25041,  first_name: "Margery Williams", id: 25041} }
      ]

      actual = Simple::Graph.resolve(query, per: 3, internal_attributes: true)

      expect(actual).to include(records: expected_records)
    end
  end

  describe "belongs_to books <- authors" do
    let(:query) do
      Simple::Graph.query("booktown.books", order: "id asc", per: 3) do
        records {
          id
          author_id
          subject_id
        }

        belongs_to :author, foreign_key: "author_id" do
          collection do
            table "booktown.authors"
          end

          # note that this only includes limited attributes
          records {
            first_name
          }
        end
      end
    end

    it "resolves a query" do
      expected_records = [
        { id: 156,  author_id: 115,     subject_id: 9, author: { first_name: "Edgar Allen" } },
        { id: 190,  author_id: 16,      subject_id: 6, author: { first_name: "Louisa May" } },
        { id: 1234, author_id: 25_041,  subject_id: 3, author: { first_name: "Margery Williams" } }
      ]

      actual = Simple::Graph.resolve(query, per: 3)

      expect(actual[:records]).to eq(expected_records)
    end
  end

  describe "belongs_to shipment <- editions" do
    let(:query) do
      Simple::Graph.query("booktown.shipments", order: "id asc", per: 1) do
        records {
          id
          customer_id
          isbn
        }

        belongs_to :edition, table: "booktown.editions", foreign_key: "isbn" do
          records {
            publication
            book_id
          }

          belongs_to :book, table: "booktown.books", foreign_key: :book_id do
            records {
              title
            }
          end
        end
      end
    end

    it "resolves a query" do
      expected_records = [
        {
          customer_id: 107,
          id: 2,
          isbn: "0394800753",
          edition: {
            book_id: 1590,
            publication: "1949-03-01",
            book: {
              title: "Bartholomew and the Oobleck"
            }
          }
        },

        {
          customer_id: 880,
          id: 56,
          isbn: "0590445065",
          edition: {
            book_id: 25_908,
            publication: "1987-03-01",
            book: {
              title: "Franklin in the Dark"
            }
          }
        }
      ]

      actual = Simple::Graph.resolve(query, per: 2)

      expect(actual[:records]).to eq(expected_records)
    end
  end
end
