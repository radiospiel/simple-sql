require "spec_helper"

describe "Simple::SQL.lock" do
  it "raises an error if not inside a transaction" do
    expect { Simple::SQL.lock!(1) }.to raise_error("You cannot use lock! outside of a transaction")
  end

  def number_of_locks
    SQL.ask "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory'"
  end

  it "locks with 2 ints" do
    SQL.transaction do
      expect { SQL.lock!(1, 2) }.to change { number_of_locks }.by(1)
    end
  end

  it "locks with 1 int" do
    SQL.transaction do
      expect { SQL.lock!(1) }.to change { number_of_locks }.by(1)
    end
  end

  it "locks converts a string key into an int key" do
    SQL.transaction do
      expect { SQL.lock!("foo", 1) }.to change { number_of_locks }.by(1)
      expect { SQL.lock!("foo") }.to change { number_of_locks }.by(1)
    end
  end

  it "accepts a timeout value" do
    SQL.transaction do
      SQL.lock!("foo", timeout: 0.000)
    end
  end
end
