Dir.glob("tasks/*.rake").each { |r| import r }

task "test:generate_fixtures" do
  FileUtils.mkdir_p "tmp"
  FileUtils.mkdir_p "spec/fixtures"

  Dir.chdir "tmp" do
  	sh "curl -L -O https://raw.githubusercontent.com/comperiosearch/booktownDemo/master/booktown.sql"
  end

  sh "dropdb booktown || true"
	sh "psql -f tmp/booktown.sql"
	sh "psql booktown -c 'alter schema public rename to booktown'"
	sh "pg_dump  --no-owner booktown > spec/fixtures/booktown.sql"
end

task "test:prepare_db" do
  sh "createdb simple-sql-test 2>&1 > /dev/null || true"
end

task default: "test:prepare_db" do
  sh "rspec"
  sh "USE_ACTIVE_RECORD=1 rspec"
  sh "LAZY_JSON=1 rspec"
  sh "rubocop -D"
end
