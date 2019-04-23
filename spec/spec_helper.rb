%w(auth authentication authorization).each do |library_name|
  path = File.expand_path("../../#{library_name}/lib", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end

ENV["RACK_ENV"] = "test"
ENV["RAILS_ENV"] = "test"

require "byebug"
require "rspec"
require "awesome_print"
Dir.glob("./spec/support/**/*.rb").sort.each { |path| load path }

require "simple/sql"

if ENV["LAZY_JSON"]
  Simple::SQL::JSON.lazy!
end

unless ENV["USE_ACTIVE_RECORD"]
  database_url = Simple::SQL::Config.determine_url

  Simple::SQL.connect! database_url
  Simple::SQL.ask "DELETE FROM users"
end

SQL = Simple::SQL
USER_COUNT = 2

ActiveRecord::Base.logger.level = Logger::DEBUG
Simple::SQL.logger.level = Logger::DEBUG

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV["CI"] != "true")
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = "random"
  config.example_status_persistence_file_path = ".rspec.data"

  config.backtrace_exclusion_patterns << /spec\/support/
  config.backtrace_exclusion_patterns << /spec_helper/
  config.backtrace_exclusion_patterns << /database_cleaner/

  config.around(:each) do |example|
    Simple::SQL.ask "TRUNCATE TABLE users, unique_users, organizations RESTART IDENTITY CASCADE"
    example.run
  end
end
