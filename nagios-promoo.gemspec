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

  spec.add_runtime_dependency     'occi-api', '>= 4.3.8', '< 5'
  spec.add_runtime_dependency     'opennebula', '>= 5.2.1', '< 6'
  spec.add_runtime_dependency     'thor', '>= 0.19.4', '< 1'
  spec.add_runtime_dependency     'yell', '>= 2.0.7', '< 3'
  spec.add_runtime_dependency     'activesupport', '>= 4.0', '< 5'
  spec.add_runtime_dependency     'httparty', '>= 0.14', '< 1'
  spec.add_runtime_dependency     'ox', '>= 2.4.9', '< 3'

  spec.add_development_dependency 'bundler', '>= 1.8', '< 2'
  spec.add_development_dependency 'rake', '>= 10.0', '< 13'
  spec.add_development_dependency 'rspec', '>= 3.0', '< 4'
  spec.add_development_dependency 'simplecov', '>= 0.13', '< 1'
  spec.add_development_dependency 'rubygems-tasks', '>= 0.2.4', '< 1'
  spec.add_development_dependency 'rubocop', '>= 0.47', '< 1'
  spec.add_development_dependency 'pry', '>= 0.10', '< 1'

  spec.required_ruby_version = '>= 1.9.3'
end
