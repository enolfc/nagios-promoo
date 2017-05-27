# Internal deps
require File.join(File.dirname(__FILE__), 'version')

module Nagios
  module Promoo
    # Namespace for AppDB-related code.
    #
    # @author Boris Parak <parak@cesnet.cz>
    module Appdb
      # Namespace for probes checking AppDB.
      #
      # @author Boris Parak <parak@cesnet.cz>
      module Probes; end
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

module Nagios
  module Promoo
    module Appdb
      # Master class for all AppDB probes.
      #
      # @author Boris Parak <parak@cesnet.cz>
      class Master < ::Thor
        class << self
          # Hack to override the help message produced by Thor.
          # https://github.com/wycats/thor/issues/261#issuecomment-16880836
          def banner(command, _namespace = nil, _subcommand = nil)
            "#{basename} appdb #{command.usage}"
          end

          def available_probes
            probes = Nagios::Promoo::Appdb::Probes.constants.collect do |probe|
              Nagios::Promoo::Appdb::Probes.const_get(probe)
            end
            probes.reject { |probe| !probe.runnable? }
          end
        end

        class_option :endpoint,
                     type: :string,
                     desc: 'Site\'s OCCI endpoint, as specified in GOCDB',
                     default: 'http://localhost:3000/'

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

        desc 'version', 'Print version of the AppDB probe set'
        def version
          puts Nagios::Promoo::Appdb::VERSION
        end
      end
    end
  end
end
