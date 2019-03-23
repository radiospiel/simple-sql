require "spec_helper"

describe "Simple::SQL logging" do
  context 'when running a slow query' do
    before do
      SQL::Logging.slow_query_treshold = 0.05
    end
    after do
      SQL::Logging.slow_query_treshold = nil
    end

    it "does not crash" do
      SQL.ask "SELECT pg_sleep(0.1)"
    end
  end
end
