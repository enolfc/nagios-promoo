# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Opennebula
      module Probes
        # Probe for checking ONe for ERRORs on hosts.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class HostErrorProbe < Nagios::Promoo::Opennebula::Probes::BaseProbe
          class << self
            def description
              ['host-error', 'Run a probe checking for ERRORs on hosts']
            end

            def options
              []
            end

            def declaration
              'host_error'
            end

            def runnable?
              true
            end
          end

          ERROR_KEYWORD = 'ERROR'.freeze

          def run(_args = [])
            Timeout.timeout(options[:timeout]) do
              errors = host_pool.select { |host| errored?(host) }
              errors.map! { |host| host['NAME'] }
              raise "HOSTs #{errors.inspect} are in state #{ERROR_KEYWORD}" if errors.count > 0
            end

            puts 'HOSTERR OK - Everything is hunky-dory'
          rescue => ex
            puts "HOSTERR CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          end

          private

          def host_pool
            host_pool = OpenNebula::HostPool.new(client)
            rc = host_pool.info
            raise rc.message if OpenNebula.is_error?(rc)

            host_pool
          end

          def errored?(host)
            host.state_str == ERROR_KEYWORD
          end
        end
      end
    end
  end
end
