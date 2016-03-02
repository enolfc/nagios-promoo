# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Opennebula::Probes::VirtualMachineProbe < Nagios::Promoo::Opennebula::Probes::BaseProbe
  class << self
    def description
      ['virtual-machine', 'Run a probe checking OpenNebula\'s XML RPC service']
    end

    def options
      [
        [:template, { type: :string, default: 'monitoring', desc: 'Name referencing a template used for monitoring purposes' }],
        [:vm_timeout, { type: :numeric, default: 180, desc: 'Timeout for VM instantiation (in seconds)' }],
        [:cleanup, { type: :boolean, default: true, desc: 'Perform clean-up before launching a new instance' }],
      ]
    end

    def declaration
      "virtual_machine"
    end

    def runnable?; true; end
  end

  VM_NAME_PREFIX = "nagios-promoo"

  def run(options, args = [])
    fail "Timeout (#{options[:timeout]}) must be higher than "\
         "vm-timeout (#{options[:vm_timeout]}) " if options[:timeout] <= options[:vm_timeout]

    vm = nil
    begin
      Timeout::timeout(options[:timeout]) {
        cleanup(options) if options[:cleanup]
        vm = create(options)
        wait4running(options, vm)
      }
    rescue => ex
      puts "VirtualMachine CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    ensure
      begin
        cleanup(options, vm) unless vm.blank?
      rescue => ex
        ## ignoring
      end
    end

    puts "VirtualMachine OK - Instance #{vm.id.inspect} of template "\
         "#{options[:template].inspect} successfully created & cleaned up"
  end

  private

  def cleanup(options, vm = nil)
    (vm && vm.id) ? shutdown_or_delete(vm) : search_and_destroy(options)
  end

  def create(options)
    template_pool = OpenNebula::TemplatePool.new(client(options))
    rc = template_pool.info_all
    fail rc.message if OpenNebula.is_error?(rc)

    template = template_pool.select { |tpl| tpl.name == options[:template] }.first
    fail "Template #{options[:template].inspect} could not be found" unless template
    vm_id = template.instantiate("#{VM_NAME_PREFIX}-#{Time.now.to_i}")
    fail vm_id.message if OpenNebula.is_error?(vm_id)

    vm = OpenNebula::VirtualMachine.new(OpenNebula::VirtualMachine.build_xml(vm_id), client(options))
    rc = vm.info
    fail rc.message if OpenNebula.is_error?(rc)

    vm
  end

  def wait4running(options, vm)
    begin
      Timeout::timeout(options[:vm_timeout]) {
        while vm.lcm_state_str != 'RUNNING' do
          fail 'Instance deployment failed (resulting state is "FAILED")' if vm.state_str == 'FAILED'
          rc = vm.info
          fail rc.message if OpenNebula.is_error?(rc)
        end
      }
    rescue Timeout::Error => ex
      puts "VirtualMachine WARNING - Execution timed out while waiting for "\
           "the instance to become active [#{options[:vm_timeout]}s]"
      exit 1
    end
  end

  def search_and_destroy(options)
    vm_pool = OpenNebula::VirtualMachinePool.new(client(options))
    rc = vm_pool.info_mine
    fail rc.message if OpenNebula.is_error?(rc)

    candidates = vm_pool.select { |vm| vm.name.start_with?(VM_NAME_PREFIX) }
    candidates.each { |vm| shutdown_or_delete(vm) }

    candidates.count
  end

  def shutdown_or_delete(vm)
    rc = (vm.lcm_state_str == 'RUNNING') ? vm.shutdown(true) : vm.delete
    fail rc.message if OpenNebula.is_error?(rc)
  end
end
