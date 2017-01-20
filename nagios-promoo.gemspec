# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nagios/promoo/version'

Gem::Specification.new do |spec|
  spec.name          = 'nagios-promoo'
  spec.version       = Nagios::Promoo::VERSION
  spec.authors       = ['Boris Parak']
  spec.email         = ['parak@cesnet.cz']
  spec.summary       = %q{Nagios Probes for Monitoring OpenNebula and OCCI}
  spec.description   = %q{Nagios Probes for Monitoring OpenNebula and OCCI}
  spec.homepage      = 'https://github.com/EGI-FCTF/nagios-promoo'
  spec.license       = 'Apache License, Version 2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency     'occi-api', '~> 4.3'
  spec.add_runtime_dependency     'opennebula', '~> 4.14'
  spec.add_runtime_dependency     'thor'
  spec.add_runtime_dependency     'yell'
  spec.add_runtime_dependency     'activesupport'
  spec.add_runtime_dependency     'httparty'
  spec.add_runtime_dependency     'ox'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'rubygems-tasks', '~> 0.2'
  spec.add_development_dependency 'rubocop', '~> 0.32'
  spec.add_development_dependency 'pry', '~> 0.10'

  spec.required_ruby_version = '>= 1.9.3'
end
