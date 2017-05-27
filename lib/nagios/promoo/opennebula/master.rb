# Deps
require 'opennebula'

# Internal deps
require File.join(File.dirname(__FILE__), 'version')

module Nagios
  module Promoo
    # Namespace for ONe-related code.
    #
    # @author Boris Parak <parak@cesnet.cz>
    module Opennebula
      # Namespace for ONe-related probes.
      #
      # @author Boris Parak <parak@cesnet.cz>
      module Probes; end
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

module Nagios
  module Promoo
    module Opennebula
      class Master < ::Thor
        class << self
          # Hack to override the help message produced by Thor.
          # https://github.com/wycats/thor/issues/261#issuecomment-16880836
          def banner(command, _namespace = nil, _subcommand = nil)
            "#{basename} opennebula #{command.usage}"
          end

          def available_probes
            Nagios::Promoo::Opennebula::Probes.constants.collect do |probe|
              Nagios::Promoo::Opennebula::Probes.const_get(probe)
            end.reject { |probe| !probe.runnable? }
          end
        end

        class_option :endpoint, type: :string,
                     desc: 'OpenNebula XML-RPC endpoint', default: 'http://localhost:2633/RPC2'
        class_option :token, type: :string, desc: 'Authentication token',
                     default: "file://#{ENV['HOME']}/.one/one_auth"

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

        desc 'version', 'Print version of the OpenNebula probe set'
        def version
          puts Nagios::Promoo::Opennebula::VERSION
        end
      end
    end
  end
end
