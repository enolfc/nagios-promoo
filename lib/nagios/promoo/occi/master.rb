# Deps
require 'occi-api'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

# Define modules
module Nagios::Promoo::Occi; end
module Nagios::Promoo::Occi::Probes; end
Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

class Nagios::Promoo::Occi::Master < ::Thor
  class << self
    # Hack to override the help message produced by Thor.
    # https://github.com/wycats/thor/issues/261#issuecomment-16880836
    def banner(command, namespace = nil, subcommand = nil)
      "#{basename} occi #{command.usage}"
    end

    def available_probes
      Nagios::Promoo::Occi::Probes.constants.collect { |probe| Nagios::Promoo::Occi::Probes.const_get(probe) }.reject { |probe| !probe.runnable? }
    end
  end

  class_option :endpoint, type: :string, desc: 'OCCI-enabled endpoint', default: 'http://localhost:3000/'
  class_option :auth, type: :string, desc: 'Authentication mechanism', enum: %w(x509-voms token), default: 'x509-voms'
  class_option :token, type: :string, desc: 'Authentication token', default: "file:///tmp/x509up_u#{`id -u`.strip}"

  available_probes.each do |probe|
    desc *probe.description
    probe.options.each do |opt|
      option opt.first, opt.last
    end
    class_eval %Q^
def #{probe.declaration}(*args)
  #{probe}.new(options).run(args)
end
^
  end

  desc 'version', 'Print version of the OCCI probe set'
  def version
    puts Nagios::Promoo::Occi::VERSION
  end
end
