Dir.glob("tasks/*.rake").each { |r| import r }


task "test:prepare_db" do
  sh "createdb simple-sql-test 2>&1 > /dev/null || true"
end

task default: "test:prepare_db" do
  sh "rspec"
  sh "USE_ACTIVE_RECORD=1 rspec"
  sh "rubocop -D"
end

task :fastspec do
  sh "SKIP_SIMPLE_COV=1 rspec --only-failures"
  sh "rspec"
end
