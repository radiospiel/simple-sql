# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "simple/graph"

describe "Simple::Graph has_many associations" do
  it "automatically loads the foreign_key data" do
    query = Simple::Graph.query("booktown.authors", order: "id asc", per: 3) do
      records do
        id
        name "first_name || ' ' || last_name"
      end

      has_one :book, foreign_key: "author_id", table: "booktown.books" do
        records do
          title
        end
      end
    end

    expected_records = [
      {
        id: 16,
        name: "Louisa May Alcott",
        book: { title: "Little Women", author_id: 16 }
      },
      {
        id: 115,
        name: "Edgar Allen Poe",
        book: { title: "The Tell-Tale Heart", author_id: 115 }
      },
      {
        id: 1111, name: "Ariel Denham",
        book: nil
      }
    ]

    actual = Simple::Graph.resolve(query, per: 3)
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(19)
  end

  it "honors conditions on the top query" do
    query = Simple::Graph.query("booktown.authors", order: "id desc", per: 3) do
      records do
        id
        name "first_name || ' ' || last_name"
      end

      has_one :book, order: "id" do
        records do
          id
          title
          author_id
        end
      end
    end

    expected_records = [
      {
        id: 1809,
        name: "Theodor Seuss Geisel",
        book: { id: 1590, title: "Bartholomew and the Oobleck", author_id: 1809 },
        #book: { id: 1608, title: "The Cat in the Hat", author_id: 1809 }
      },
      {
        id: 1644,
        name: "Burne Hogarth",
        book: { id: 2038, title: "Dynamic Anatomy", author_id: 1644 }
      },
      {
        id: 1213, name: "Andrew Brookins",
        book: nil
      }
    ]

    actual = Simple::Graph.resolve(query, conditions: [id: [1213, 1644, 1809]])
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(3)
  end

  it "honors order on the associated query" do
    query = Simple::Graph.query("booktown.authors", order: "id desc", per: 3) do
      records do
        id
        name "first_name || ' ' || last_name"
      end

      has_one :book, foreign_key: "author_id", table: "booktown.books", order: "id desc" do
        records do
          id
          title
          author_id
        end
      end
    end

    expected_records = [
      {
        id: 1809,
        name: "Theodor Seuss Geisel",
        book: { id: 1608, title: "The Cat in the Hat", author_id: 1809 }
      },
      {
        id: 1644,
        name: "Burne Hogarth",
        book: { id: 2038, title: "Dynamic Anatomy", author_id: 1644 }
      }
    ]

    actual = Simple::Graph.resolve(query, conditions: [id: [1644, 1809]])
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(2)
  end
end
