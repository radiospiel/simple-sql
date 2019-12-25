# This file is part of the sinatra-sse ruby gem.
#
# Copyright (c) 2016, 2017 @radiospiel, mediapeers Gem
# Distributed under the terms of the modified BSD license, see LICENSE.BSD

Gem::Specification.new do |gem|
  gem.name     = "simple-sql"
  gem.version  = File.read "VERSION"

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

  gem.add_dependency 'pg_array_parser', '~> 0', '>= 0.0.9'
  gem.add_dependency 'pg', '~> 0.20'
  gem.add_dependency 'expectation', '~> 1'

  gem.add_dependency 'digest-crc', '~> 0'

  # during tests we check the SIMPLE_SQL_ACTIVERECORD_SPECS environment setting.
  # Run make tests to run all tests
  if ENV["SIMPLE_SQL_ACTIVERECORD_SPECS"]
    gem.add_dependency 'activerecord', '> 4.2', *(ENV["SIMPLE_SQL_ACTIVERECORD_SPECS"].split(","))
  else
    gem.add_dependency 'activerecord', '> 4.2', '< 7'
  end

  # optional gems (required by some of the parts)

  # development gems
  gem.add_development_dependency 'pg', '0.20'
  gem.add_development_dependency 'rake', '~> 11'
  gem.add_development_dependency 'rspec', '~> 3.7'
  gem.add_development_dependency 'rubocop', '~> 0.61.1'
  gem.add_development_dependency 'simplecov', '~> 0'
end
