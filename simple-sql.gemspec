# This file is part of the sinatra-sse ruby gem.
#
# Copyright (c) 2016, 2017 @radiospiel, mediapeers Gem
# Distributed under the terms of the modified BSD license, see LICENSE.BSD

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'simple/sql/version'

Gem::Specification.new do |gem|
  gem.name     = "simple-sql"
  gem.version  = Simple::SQL::VERSION

  gem.authors  = [ "radiospiel", "mediapeers GmbH" ]
  gem.email    = "eno@radiospiel.org"
  gem.homepage = "http://github.com/radiospiel/simple-sql"
  gem.summary  = "SQL with a simple interface"

  gem.description = "SQL with a simple interface. Postgres only."

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths =  %w(lib)

  # executables are used for development purposes only
  gem.executables   = []

  gem.required_ruby_version = '~> 2.3'

  gem.add_dependency 'pg_array_parser', '~> 0'
  gem.add_dependency 'pg', '~> 0.20'
  gem.add_dependency 'expectation', '~> 1'

  gem.add_dependency 'digest-crc', '~> 0'

  gem.add_dependency 'activerecord', '~> 4'

  # optional gems (required by some of the parts)

  # development gems
  gem.add_development_dependency 'pg', '0.20'
  gem.add_development_dependency 'rake', '~> 11'
  gem.add_development_dependency 'rspec', '~> 3.7'
  gem.add_development_dependency 'rubocop', '~> 0.61.1'
  gem.add_development_dependency 'simplecov', '~> 0'

  gem.add_development_dependency 'memory_profiler', '~> 0.9.12'
end
