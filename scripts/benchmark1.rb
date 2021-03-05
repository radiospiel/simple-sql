require "benchmark"
require "simple-sql"

ENV["DATABASE_URL"] = "postgres://admin:admin@localhost/um_development"

Simple::SQL.connect
# require 'stackprof'# added

Benchmark.bmbm do |x|
  x.report("1000x Simple::SQL HStore performance for 100 users") do
    1000.times { Simple::SQL.all("SELECT id, meta_data FROM users limit 100") }
  end

  x.report("1000x Simple::SQL HStore::varchar performance for 100 users") do
    1000.times { Simple::SQL.all("SELECT id, meta_data::varchar FROM users limit 100") }
  end

  x.report("1000x Simple::SQL HStore as jsonb performance for 100 users") do
    1000.times { Simple::SQL.all("SELECT id, to_jsonb(meta_data) FROM users limit 100") }
  end

  x.report("1000x Simple::SQL timestamp performance for 100 users") do
    1000.times { Simple::SQL.all("SELECT id, created_at FROM users limit 100") }
  end

  x.report("1000x Simple::SQL timestamp::varchar performance for 100 users") do
    1000.times { Simple::SQL.all("SELECT id, created_at::varchar FROM users limit 100") }
  end
end
