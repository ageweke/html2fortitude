# -*- encoding: utf-8 -*-
require File.expand_path('../lib/html2fortitude/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Norman Clarke", "Stefan Natchev", "Andrew Geweke"]
  gem.email         = ["norman@njclarke.com", "stefan.natchev@gmail.com", "andrew@geweke.org"]
  gem.description   = %q{Converts HTML into Fortitude}
  gem.summary       = %q{Converts HTML into Fortitude}
  gem.homepage      = "http://github.com/ageweke/html2fortitude"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "html2fortitude"
  gem.require_paths = ["lib"]
  gem.version       = Html2fortitude::VERSION

  gem.required_ruby_version = '>= 1.9.2'

  gem.add_dependency 'activesupport', '>= 3.0.0'
  gem.add_dependency 'nokogiri', '~> 1.6.0'
  gem.add_dependency 'erubis', '~> 2.7.0'
  gem.add_dependency 'ruby_parser', '~> 3.4.1'
  gem.add_dependency 'trollop', '~> 2.0.0'
  # TODO ageweke: eliminate
  gem.add_dependency 'haml', '~> 4.0.0'
  gem.add_development_dependency 'simplecov', '~> 0.7.1'
  gem.add_development_dependency 'minitest', '~> 4.4.0'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 2.14'
end
