# Deps
require 'occi-api'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

# Define modules
module Nagios::Promoo::Occi; end
module Nagios::Promoo::Occi::Probes; end
Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

class Nagios::Promoo::Occi::Master < ::Thor
  class_option :endpoint, type: :string, desc: 'OCCI-enabled endpoint', default: 'http://localhost:3000/'
  class_option :auth, type: :string, desc: 'Authentication mechanism', enum: %w(basic x509 x509-voms), default: 'x509-voms'
  class_option :token, type: :string, desc: 'Authentication token', default: "file:///tmp/x509up_u#{`id -u`.strip}"

  desc *Nagios::Promoo::Occi::Probes::BasicKindsProbe.description
  Nagios::Promoo::Occi::Probes::BasicKindsProbe.options.each do |opt|
    option opt.first, opt.last
  end
  class_eval %Q^
def #{Nagios::Promoo::Occi::Probes::BasicKindsProbe.declaration}(*args)
  Nagios::Promoo::Occi::Probes::BasicKindsProbe.new.run(args)
end
^

  desc 'version', 'Print version of the OCCI probe set'
  def version
    puts Nagios::Promoo::Occi::VERSION
  end

  class << self
    # Hack to override the help message produced by Thor.
    # https://github.com/wycats/thor/issues/261#issuecomment-16880836
    def banner(command, namespace = nil, subcommand = nil)
      "#{basename} occi #{command.usage}"
    end
  end
end
