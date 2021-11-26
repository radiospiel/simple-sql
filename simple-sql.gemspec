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
  gem.add_dependency 'pg', '~> 1.1'
  gem.add_dependency 'expectation', '~> 1'

  gem.add_dependency 'digest-crc', '~> 0'
  gem.add_dependency 'simple-immutable', '~> 1.0'

  # during tests we check the SIMPLE_SQL_ACTIVERECORD_SPECS environment setting.
  # Run make tests to run all tests
  if ENV["SIMPLE_SQL_ACTIVERECORD_SPECS"]
    gem.add_dependency 'activerecord', '>= 5.2.4.5', *(ENV["SIMPLE_SQL_ACTIVERECORD_SPECS"].split(","))
  else
    gem.add_dependency 'activerecord', '>= 6', '<= 6.1.4'
  end
end
