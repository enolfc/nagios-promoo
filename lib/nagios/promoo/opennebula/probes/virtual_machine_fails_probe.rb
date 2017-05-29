# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Opennebula
      module Probes
        # Probe for checking ONe for FAILED virtual machines.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class VirtualMachineFailsProbe < Nagios::Promoo::Opennebula::Probes::BaseProbe
          class << self
            def description
              ['virtual-machine-fails', 'Run a probe checking for FAILED virtual machines']
            end

            def options
              []
            end

            def declaration
              'virtual_machine_fails'
            end

            def runnable?
              true
            end
          end

          FAIL_KEYWORD = 'FAILURE'.freeze

          def run(_args = [])
            Timeout.timeout(options[:timeout]) do
              fails = virtual_machine_pool.select { |vm| failed?(vm) }
              fails.map!(&:id)
              raise "Virtual machines #{fails.inspect} are in a FAILED state" if fails.count > 0
            end

            puts 'VMFAILS OK - Everything is hunky-dory'
          rescue => ex
            puts "VMFAILS CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          end

          private

          def virtual_machine_pool
            vm_pool = OpenNebula::VirtualMachinePool.new(client)
            rc = vm_pool.info_all
            raise rc.message if OpenNebula.is_error?(rc)

            vm_pool
          end

          def failed?(vm)
            vm.lcm_state_str.include?(FAIL_KEYWORD) || vm.state_str.include?(FAIL_KEYWORD)
          end
        end
      end
    end
  end
end
