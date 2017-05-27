require 'rubygems/tasks'
require 'rubocop/rake_task'

Gem::Tasks.new(build: { tar: true, zip: true }, sign: { checksum: true, pgp: false })
RuboCop::RakeTask.new

task default: 'rubocop'
