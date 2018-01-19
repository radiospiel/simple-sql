require "rubocop/rake_task"
require "rspec/core/rake_task"

Dir.glob("tasks/*.rake").each { |r| import r }

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

task default: [:spec, :rubocop]
