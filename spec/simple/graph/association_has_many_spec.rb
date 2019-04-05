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

      has_many :books do
        records do
          title
        end
      end
    end

    expected_records = [
      {
        id: 16,
        name: "Louisa May Alcott",
        books: [{ title: "Little Women", author_id: 16 }]
      },
      {
        id: 115,
        name: "Edgar Allen Poe",
        books: [{ title: "The Tell-Tale Heart", author_id: 115 }]
      },
      {
        id: 1111, name: "Ariel Denham",
        books: []
      }
    ]

    actual = Simple::Graph.resolve(query, per: 3)
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(19)
  end

  it "returns the expected records" do
    query = Simple::Graph.query("booktown.authors", order: "id asc", per: 3) do
      records do
        id
        name "first_name || ' ' || last_name"
      end

      has_many :books, foreign_key: "author_id", table: "booktown.books" do
        records do
          title
          author_id
        end
      end
    end

    expected_records = [
      {
        id: 16,
        name: "Louisa May Alcott",
        books: [{ title: "Little Women", author_id: 16 }]
      },
      {
        id: 115,
        name: "Edgar Allen Poe",
        books: [{ title: "The Tell-Tale Heart", author_id: 115 }]
      },
      {
        id: 1111, name: "Ariel Denham",
        books: []
      },
      {
        id: 1212,
        name: "John Worsley",
        books: [{ title: "Practical PostgreSQL", author_id: 1212 }]
      },
      {
        id: 1213, name: "Andrew Brookins",
        books: []
      },
      {
        id: 1533, name: "Richard Brautigan",
        books: []
      },
      {
        id: 1644,
        name: "Burne Hogarth",
        books: [{ title: "Dynamic Anatomy", author_id: 1644 }]
      },
      {
        id: 1717, name: "Poppy Z. Brite",
        books: []
      },
      {
        id: 1809,
        name: "Theodor Seuss Geisel",
        books: [{ title: "The Cat in the Hat", author_id: 1809 },
                { title: "Bartholomew and the Oobleck", author_id: 1809 }]
      },
      {
        id: 1866,
        name: "Frank Herbert",
        books: [{ title: "Dune", author_id: 1866 }]
      }
    ]

    actual = Simple::Graph.resolve(query, per: 10)
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(19)
  end

  it "honors conditions on the top query" do
    query = Simple::Graph.query("booktown.authors", order: "id desc", per: 3) do
      records do
        id
        name "first_name || ' ' || last_name"
      end

      has_many :books, foreign_key: "author_id", table: "booktown.books", order: "id" do
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
        books: [
          { id: 1590, title: "Bartholomew and the Oobleck", author_id: 1809 },
          { id: 1608, title: "The Cat in the Hat", author_id: 1809 }
        ]
      },
      {
        id: 1644,
        name: "Burne Hogarth",
        books: [{ id: 2038, title: "Dynamic Anatomy", author_id: 1644 }]
      },
      {
        id: 1213, name: "Andrew Brookins",
        books: []
      }
    ]

    actual = Simple::Graph.resolve(query, conditions: [id: [1213, 1644, 1809]])
    expect(actual).to include(records: expected_records)
    expect(actual[:total_count]).to eq(3)
  end
end
