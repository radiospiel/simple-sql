require "spec_helper"

describe "Simple::SQL::Config" do
  describe ".determine_url" do
    xit "reads config/database.yml" do
      expect(SQL::Config.determine_url).to eq "postgres://127.0.0.1/simple-sql-test"
    end
  end

  describe ".parse_url" do
    it "parses a DATABASE_URL" do
      parsed = SQL::Config.parse_url "postgres://foo:bar@server/database"
      expect(parsed).to eq(
          dbname: "database",
          host: "server",
          password: "bar",
          sslmode: "prefer",
          user: "foo")
    end

    it "may enforce SSL" do
      parsed = SQL::Config.parse_url "postgress://foo:bar@server/database"
      expect(parsed).to eq(
          dbname: "database",
          host: "server",
          password: "bar",
          sslmode: "require",
          user: "foo")
    end
  end
end
