# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Appdb
      module Probes
        # Probe for checking flavors/sizes in AppDB.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class SizesProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
          class << self
            def description
              ['sizes', 'Run a probe checking size/flavor/resource templates in AppDB']
            end

            def options
              []
            end

            def declaration
              'sizes'
            end

            def runnable?
              true
            end
          end

          def run(_args = [])
            count = Timeout.timeout(options[:timeout]) { sizes_by_endpoint.count }
            if count < 1
              puts 'SIZES CRITICAL - No size/flavor/resource templates found in AppDB'
              exit 2
            end

            puts "SIZES OK - Found #{count} size/flavor/resource templates in AppDB"
          rescue => ex
            puts "SIZES UNKNOWN - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 3
          end
        end
      end
    end
  end
end
