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

SQL = Simple::SQL

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV["CI"] != "true")
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.include FactoryGirl::Syntax::Methods
  config.order = "random"
end
