require "spec_helper"

describe "Simple::SQL.locked" do
  xit 'acquires and releases an advisory lock' do # pending: "This code was manually tested"
    one = Simple::SQL.locked(4711) do
      Simple::SQL.ask "SELECT 1"
    end

    expect(one).to eq(1)
  end

  xit 'releases the lock after an exception' do # pending: "This code was manually tested"
    begin
      Simple::SQL.locked(4711) do
        raise "HU"
      end
    rescue
    end
  end
end
