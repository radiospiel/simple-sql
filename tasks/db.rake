namespace :db do
  task :environment do
    require "simple/sql"
    Simple::SQL::Config.set_environment!
  end

  task create: :environment do
    sh "createdb #{ENV['PGDATABASE']}"
  end

  task drop: :environment do
    sh "dropdb #{ENV['PGDATABASE']}"
  end

  # load the sakila example database
  task "prepare:sakila" => :environment do
    sh "createdb #{ENV['PGDATABASE']} || true"
    sh "psql -c 'DROP SCHEMA IF EXISTS sakila CASCADE; CREATE SCHEMA IF NOT EXISTS sakila'"
    urls = [
      "https://raw.githubusercontent.com/jOOQ/jOOQ/master/jOOQ-examples/Sakila/postgres-sakila-db/postgres-sakila-schema.sql",
      "https://raw.githubusercontent.com/jOOQ/jOOQ/master/jOOQ-examples/Sakila/postgres-sakila-db/postgres-sakila-insert-data.sql"
    ]
    urls.each do |url|
      sh "curl -s -L #{url} | sed 's/search_path = public/search_path = sakila/g' | psql"
    end

    sh "(echo 'DROP SCHEMA IF EXISTS sakila CASCADE;'; pg_dump --no-owner --schema=sakila) > spec/fixtures/sakila.sql"
  end

  task "prepare:booktown" => :environment do
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

  task "fixtures:load" => :environment do
    sh "psql < spec/fixtures/sakila.sql > /dev/null 2>&1"
    sh "psql < spec/fixtures/booktown.sql > /dev/null 2>&1"
    sh "psql < spec/fixtures/booktown-adjustments.sql > /dev/null 2>&1"
  end
end
