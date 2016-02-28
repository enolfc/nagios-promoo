# Deps
require 'opennebula'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

# Define modules
module Nagios::Promoo::Opennebula; end
module Nagios::Promoo::Opennebula::Probes; end
Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

class Nagios::Promoo::Opennebula::Master < ::Thor
  class_option :endpoint, type: :string, desc: 'OpenNebula XML-RPC endpoint', default: 'http://localhost:2633/RPC2'
  class_option :token, type: :string, desc: 'Authentication token', default: 'file:///var/lib/one/.one/one_auth'

  desc 'xmlrpc-health', 'Run a probe checking on OpenNebula\'s XML RPC service'
  def xmlrpc_health
    puts 'Everything is hunky-dory!'
  end

  desc 'version', 'Print version of the OpenNebula probe set'
  def version
    puts Nagios::Promoo::Opennebula::VERSION
  end

  class << self
    # Hack to override the help message produced by Thor.
    # https://github.com/wycats/thor/issues/261#issuecomment-16880836
    def banner(command, namespace = nil, subcommand = nil)
      "#{basename} opennebula #{command.usage}"
    end
  end
end
