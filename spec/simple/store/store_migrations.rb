Simple::SQL.exec <<~SQL
  DROP SCHEMA IF EXISTS simple_store CASCADE;
SQL

Simple::SQL.exec <<~SQL
  CREATE SCHEMA IF NOT EXISTS simple_store;

  CREATE TABLE simple_store.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    city VARCHAR
  );

  CREATE TABLE simple_store.users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations (id),
    role_id INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    meta_data JSONB,
    access_level access_level,
    type VARCHAR NOT NULL,
    created_at timestamp,
    updated_at timestamp
  );
SQL

Simple::Store::Metamodel.register "User", table_name: "simple_store.users" do
  attribute :full_name, kind: :virtual
end

Simple::Store::Metamodel.register_virtual_attributes "User" do
  def full_name(user)
    "#{user.first_name} #{user.last_name}"
  end
end

Simple::Store::Metamodel.register "Organization", table_name: "simple_store.organizations" do
  attribute :city, writable: false
end
