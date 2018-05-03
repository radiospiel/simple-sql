%w(auth authentication authorization).each do |library_name|
  path = File.expand_path("../../#{library_name}/lib", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end

ENV["RACK_ENV"] = "test"
ENV["RAILS_ENV"] = "test"

require "rspec"
require "awesome_print"
Dir.glob("./spec/support/**/*.rb").sort.each { |path| load path }

require "simple/sql"

unless ENV["USE_ACTIVE_RECORD"]
  Simple::SQL.connect!
  Simple::SQL.ask "DELETE FROM users"
end

SQL = Simple::SQL
USER_COUNT = 2

ActiveRecord::Base.logger.level = Logger::INFO

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec.status"

  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV["CI"] != "true")
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = "random"
  config.around(:each) do |example|
    Simple::SQL.ask "DELETE FROM users"
    Simple::SQL.ask "DELETE FROM unique_users"
    example.run
  end
end
