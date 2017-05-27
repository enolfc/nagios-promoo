# Deps
require 'occi-api'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

module Nagios
  module Promoo
    # Namespace for OCCI-related code.
    #
    # @author Boris Parak <parak@cesnet.cz>
    module Occi
      # Namespace for OCCI-related probes.
      #
      # @author Boris Parak <parak@cesnet.cz>
      module Probes; end
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

module Nagios
  module Promoo
    module Occi
      class Master < ::Thor
        class << self
          # Hack to override the help message produced by Thor.
          # https://github.com/wycats/thor/issues/261#issuecomment-16880836
          def banner(command, _namespace = nil, _subcommand = nil)
            "#{basename} occi #{command.usage}"
          end

          def available_probes
            Nagios::Promoo::Occi::Probes.constants.collect do |probe|
              Nagios::Promoo::Occi::Probes.const_get(probe)
            end.reject { |probe| !probe.runnable? }
          end
        end

        class_option :endpoint, type: :string, desc: 'OCCI-enabled endpoint', default: 'http://localhost:3000/'
        class_option :auth, type: :string, desc: 'Authentication mechanism',
                     enum: %w(x509-voms), default: 'x509-voms'
        class_option :token, type: :string, desc: 'Authentication token',
                     default: "file:///tmp/x509up_u#{`id -u`.strip}"

        available_probes.each do |probe|
          desc(*probe.description)
          probe.options.each do |opt|
            option opt.first, opt.last
          end

          class_eval %^
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
    end
  end
end
