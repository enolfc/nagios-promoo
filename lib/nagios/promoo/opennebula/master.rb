# Deps
require 'opennebula'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

# Define modules
module Nagios::Promoo::Opennebula; end
module Nagios::Promoo::Opennebula::Probes; end
Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

class Nagios::Promoo::Opennebula::Master < ::Thor
  class << self
    # Hack to override the help message produced by Thor.
    # https://github.com/wycats/thor/issues/261#issuecomment-16880836
    def banner(command, namespace = nil, subcommand = nil)
      "#{basename} opennebula #{command.usage}"
    end

    def available_probes
      Nagios::Promoo::Opennebula::Probes.constants.collect { |probe| Nagios::Promoo::Opennebula::Probes.const_get(probe) }.reject { |probe| !probe.runnable? }
    end
  end

  class_option :endpoint, type: :string, desc: 'OpenNebula XML-RPC endpoint', default: 'http://localhost:2633/RPC2'
  class_option :token, type: :string, desc: 'Authentication token', default: 'file:///var/lib/one/.one/one_auth'

  available_probes.each do |probe|
    desc *probe.description
    probe.options.each do |opt|
      option opt.first, opt.last
    end
    class_eval %Q^
def #{probe.declaration}(*args)
  #{probe}.new.run(options, args)
end
^
  end

  desc 'version', 'Print version of the OpenNebula probe set'
  def version
    puts Nagios::Promoo::Opennebula::VERSION
  end
end
