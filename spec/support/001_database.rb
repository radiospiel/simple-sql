# connect to the database and setup the schema
require "active_record"
require "yaml"
abc = YAML.load_file("config/database.yml")
ActiveRecord::Base.establish_connection(abc["test"])

# Remove after migration to Rails 5
ActiveRecord::Base.raise_in_transactional_callbacks = true

ActiveRecord::Base.logger = Logger.new("log/test.log")

ActiveRecord::Schema.define do
  self.verbose = false

  execute "DROP SCHEMA public CASCADE;"
  execute "CREATE SCHEMA public;"
  execute "CREATE EXTENSION IF NOT EXISTS hstore;"

  execute <<-SQL
    DROP TYPE IF EXISTS access_level;
    CREATE TYPE access_level AS ENUM (
        'private',
        'company',
        'viewable',
        'accessible'
    );
  SQL

  create_table :users, force: true do |t|
    t.integer   :role_id
    t.string    :first_name
    t.string    :last_name
    t.hstore    :meta_data
    t.column    :access_level, :access_level

    t.timestamps null: true
  end
end
