# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Appdb
      module Probes
        # Probe for checking appliance availability in AppDB.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class AppliancesProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
          class << self
            def description
              ['appliances', 'Run a probe checking appliances in AppDB']
            end

            def options
              [
                [
                  :vo,
                  {
                    type: :string,
                    required: true,
                    desc: 'Virtual Organization name (used to select the appropriate set of appliances)'
                  }
                ]
              ]
            end

            def declaration
              'appliances'
            end

            def runnable?
              true
            end
          end

          def run(_args = [])
            count = Timeout.timeout(options[:timeout]) { appliances_by_endpoint(options[:vo]).count }
            if count < 1
              puts "APPLIANCES CRITICAL - No appliances found for VO #{options[:vo]} in AppDB"
              exit 2
            end

            puts "APPLIANCES OK - Found #{count} appliances for VO #{options[:vo]} in AppDB"
          rescue => ex
            puts "APPLIANCES UNKNOWN - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 3
          end
        end
      end
    end
  end
end
