require "spec_helper"

describe "Simple::SQL.locked" do
  LOCK = 4711

  specify { expect { |b| SQL.locked(LOCK, &b) }.to yield_with_no_args }

  it 'acquires and releases an advisory lock' do
    expect(SQL).to receive(:ask).with("SELECT pg_advisory_lock(#{LOCK})").once
    expect(SQL).to receive(:ask).with("SELECT pg_advisory_unlock(#{LOCK})").once

    Simple::SQL.locked(LOCK) do
      puts 'work while locked'
    end
  end
end
