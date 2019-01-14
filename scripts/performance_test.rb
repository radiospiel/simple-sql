#!/usr/bin/env ruby
require "bundler"
Bundler.require
require "simple-sql"
require "simple-store"

require "benchmark"

n = 1000

Simple::SQL.connect!
Simple::SQL.exec <<~SQL
  DROP SCHEMA IF EXISTS performance CASCADE;
  CREATE SCHEMA IF NOT EXISTS performance;

  CREATE TABLE performance.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    city VARCHAR
  );

  CREATE TABLE performance.users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES performance.organizations (id),
    role_id INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    meta_data JSONB,
    type VARCHAR NOT NULL,
    created_at timestamp,
    updated_at timestamp
  );
SQL

Simple::Store::Metamodel.register "Organization", table_name: "performance.organizations" do
  attribute :city, writable: false
end

Simple::Store::Metamodel.register "User", table_name: "performance.users" do
  attribute :zip_code, type: :text
end

$counter = 0

def user
  $counter += 1
  {
    first_name: "first#{$counter}", last_name: "last#{$counter}", zip_code: "BE#{$counter}"
  }
end

def organization
  $counter += 1
  {
    name: "name#{$counter}"
  }
end

def organizations(n)
  1.upto(n).map { organization }
end

def users(n)
  1.upto(n).map { user }
end

def clear
  Simple::SQL.ask "TRUNCATE TABLE performance.users, performance.organizations RESTART IDENTITY CASCADE"
end

N = 1000

if false

  Benchmark.bm(30) do |x|
    x.report("build #{N} organizations")        { clear;                            N.times { Simple::Store.build "Organization", organization; } }
    x.report("build #{N} users")                { clear;                            N.times { Simple::Store.build "User", user; } }
    x.report("create #{N} organizations")       { clear;                            N.times { Simple::Store.create! "Organization", organization; } }
    x.report("create #{N} users")               { clear;                            N.times { Simple::Store.create! "User", user; } }
    x.report("create #{N} orgs/w transaction")  { clear; Simple::SQL.transaction { N.times { Simple::Store.create! "Organization", organization; }; } }
    x.report("create #{N} users/w transaction") { clear; Simple::SQL.transaction { N.times { Simple::Store.create! "User", user; };                 } }
    x.report("mass-create #{N} orgs")           { clear;                                       Simple::Store.create! "Organization", organizations(N) }
    x.report("mass-create #{N} users")          { clear;                                       Simple::Store.create! "User", users(N) }
  end

end

clear
Simple::Store.create! "Organization", organizations(N)
Simple::Store.create! "User", users(N)

require "pp"

Benchmark.bmbm(30) do |x|
  x.report("load #{N} organizations")       { Simple::Store.all "SELECT * FROM performance.organizations" }
  x.report("load #{N} users")               { Simple::Store.all "SELECT * FROM performance.users" }
end
