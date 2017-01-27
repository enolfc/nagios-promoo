# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Opennebula::Probes::VirtualMachineProbe < Nagios::Promoo::Opennebula::Probes::BaseProbe
  class << self
    def description
      ['virtual-machine', 'Run a probe instantiating a test instance in OpenNebula']
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

  def run(args = [])
    fail "Timeout (#{options[:timeout]}) must be higher than "\
         "vm-timeout (#{options[:vm_timeout]}) " if options[:timeout] <= options[:vm_timeout]

    @_virtual_machine = nil

    Timeout::timeout(options[:timeout]) {
      cleanup if options[:cleanup]
      create
      wait4running
    }

    puts "VirtualMachine OK - Instance #{@_virtual_machine.id.inspect} of template "\
         "#{options[:template].inspect} successfully created & cleaned up"
  rescue => ex
    puts "VirtualMachine CRITICAL - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 2
  ensure
    begin
      cleanup @_virtual_machine unless @_virtual_machine.blank?
    rescue => ex
      ## ignoring
    end
  end

  private

  def cleanup(virtual_machine = nil)
    virtual_machine ? shutdown_or_delete(virtual_machine) : search_and_destroy
  end

  def create
    template_pool = OpenNebula::TemplatePool.new(client)
    rc = template_pool.info_all
    fail rc.message if OpenNebula.is_error?(rc)

    template = template_pool.select { |tpl| tpl.name == options[:template] }.first
    fail "Template #{options[:template].inspect} could not be found" unless template

    vm_id = template.instantiate("#{VM_NAME_PREFIX}-#{Time.now.to_i}")
    fail vm_id.message if OpenNebula.is_error?(vm_id)

    virtual_machine = OpenNebula::VirtualMachine.new(OpenNebula::VirtualMachine.build_xml(vm_id), client)
    rc = virtual_machine.info
    fail rc.message if OpenNebula.is_error?(rc)

    @_virtual_machine = virtual_machine
  end

  def wait4running
    Timeout::timeout(options[:vm_timeout]) {
      while @_virtual_machine.lcm_state_str != 'RUNNING' do
        fail 'Instance deployment failed (resulting state is "*_FAILED")' if @_virtual_machine.lcm_state_str.include?('FAILURE')
        rc = @_virtual_machine.info
        fail rc.message if OpenNebula.is_error?(rc)
      end
    }
  rescue Timeout::Error => ex
    puts "VirtualMachine WARNING - Execution timed out while waiting for " \
         "the instance to become active [#{options[:vm_timeout]}s]"
    exit 1
  end

  def search_and_destroy
    vm_pool = OpenNebula::VirtualMachinePool.new(client)
    rc = vm_pool.info_mine
    fail rc.message if OpenNebula.is_error?(rc)

    candidates = vm_pool.select { |vm| vm.name.start_with?(VM_NAME_PREFIX) }
    candidates.each { |vm| shutdown_or_delete(vm) }

    candidates.count
  end

  def shutdown_or_delete(virtual_machine)
    rc = virtual_machine.terminate true
    fail rc.message if OpenNebula.is_error?(rc)
  end
end
