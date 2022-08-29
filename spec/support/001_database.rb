# connect to the database and setup the schema
require "active_record"

# it is important to require simple-sql here to activate monkey patches
require "simple-sql"

require "yaml"
abc = if Psych::VERSION > '4.0'
  YAML.load_file "config/database.yml" , aliases: true
else
  YAML.load_file "config/database.yml"
end

ActiveRecord::Base.establish_connection(abc["test"])

if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks=)
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

ActiveRecord::Base.logger = Logger.new("log/test.log")

ActiveRecord::Schema.define do
  self.verbose = false

  execute <<~SQL
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS hstore;

    DROP TYPE IF EXISTS access_level;
    CREATE TYPE access_level AS ENUM (
        'private',
        'company',
        'viewable',
        'accessible'
    );

    CREATE TABLE organizations (
      id SERIAL PRIMARY KEY,
      name VARCHAR
    );

    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      organization_id INTEGER REFERENCES organizations (id),
      role_id INTEGER,
      first_name VARCHAR,
      last_name VARCHAR,
      metadata JSONB,
      access_level access_level,
      created_at timestamp,
      updated_at timestamp
    );

    CREATE TABLE unique_users (
      id SERIAL PRIMARY KEY,
      first_name VARCHAR,
      last_name VARCHAR
    );

    CREATE UNIQUE INDEX unique_users_ix1 ON unique_users(first_name, last_name)
  SQL
end
