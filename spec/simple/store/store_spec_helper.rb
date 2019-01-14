require "spec_helper"
require "simple/store"

require_relative "store_migrations"

module StoreSpecHelper
  def self.included(spec)
    spec.before do
      Simple::SQL.ask "TRUNCATE TABLE simple_store.users, simple_store.organizations RESTART IDENTITY CASCADE"
    end
  end
  
  # Helper to verify against InvalidArguments
  def expect_invalid_arguments(e, errors, check_keys: true)
    expect(e).to be_a(Simple::Store::InvalidArguments)
    expect(e.errors).to be_a(Hash)
    expect(e.message).to be_a(String)

    return unless errors

    expect(e.errors.keys).to contain_exactly(*errors.keys) if check_keys
    expect(e.errors).to include(errors)
  end

  # Helper to verify against RecordNotFound
  def expect_records_not_found(e, type, missing_ids)
    expect(e).to be_a(Simple::Store::RecordNotFound)
    # expect(e.type).to eq(type)
    expect(e.missing_ids).to contain_exactly(*missing_ids)
    expect(e.message).to be_a(String)
  end
end
