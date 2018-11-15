#!/usr/bin/env ruby
require "bundler"
Bundler.require
require "simple-sql"
require "simple-store"

require "benchmark"

module X
  def s
    "foo"
  end
end

class XX
  include X
end

N = 1_000_000
Benchmark.bm(30) do |bm|
  bm.report("extend")        { N.times { x = Object.new; x.extend(X); x.s; } }
  bm.report("custom class")  { N.times { x = XX.new; x.s; } }
end
