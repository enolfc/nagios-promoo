# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Occi
      module Probes
        class MixinsProbe < Nagios::Promoo::Occi::Probes::BaseProbe
          class << self
            def description
              ['mixins', 'Run a probe checking for mandatory OCCI mixin definitions']
            end

            def options
              [
                [
                  :mixins,
                  {
                    type: :string, enum: %w(infra context all),
                    default: 'all', desc: 'Collection of mandatory mixins to check'
                  }
                ],
                [
                  :optional,
                  {
                    type: :array, default: [],
                    desc: 'Identifiers of optional mixins (optional by force)'
                  }
                ]
              ]
            end

            def declaration
              'mixins'
            end

            def runnable?
              true
            end
          end

          INFRA_MIXINS = %w(
            http://schemas.ogf.org/occi/infrastructure#os_tpl
            http://schemas.ogf.org/occi/infrastructure#resource_tpl
          ).freeze

          CONTEXT_MIXINS = %w(
            http://schemas.openstack.org/instance/credentials#public_key
            http://schemas.openstack.org/compute/instance#user_data
          ).freeze

          def run(_args = [])
            mixins = []
            mixins += INFRA_MIXINS if %w(infra all).include?(options[:mixins])
            mixins += CONTEXT_MIXINS if %w(context all).include?(options[:mixins])
            mixins -= options[:optional] if options[:optional]

            Timeout.timeout(options[:timeout]) do
              mixins.each { |mixin| raise "#{mixin.inspect} is missing" unless client.model.get_by_id(mixin, true) }
            end

            puts 'MIXINS OK - All specified OCCI mixins were found'
          rescue => ex
            puts "MIXINS CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          end
        end
      end
    end
  end
end
