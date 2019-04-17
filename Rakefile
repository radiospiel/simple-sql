Dir.glob("tasks/*.rake").each { |r| import r }

task default: "test:prepare_db" do
  sh "rspec"
  sh "USE_ACTIVE_RECORD=1 rspec"
  sh "bundle exec rubocop -D"
end
