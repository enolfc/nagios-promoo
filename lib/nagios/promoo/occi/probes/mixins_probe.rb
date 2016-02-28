# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Occi::Probes::MixinsProbe < Nagios::Promoo::Occi::Probes::BaseProbe
  class << self
    def description
      ['mixins', 'Run a probe checking for mandatory OCCI mixin definitions']
    end

    def options
      [
        [:mixins, { type: :string, enum: %w(infra context all), default: 'all', desc: 'Collection of mandatory mixins to check' }],
        [:optional, { type: :array, default: [], desc: 'Identifiers of optional mixins (optional by force)' }]
      ]
    end

    def declaration
      "mixins"
    end

    def runnable?; true; end
  end

  INFRA_MIXINS = %w(
    http://schemas.ogf.org/occi/infrastructure#os_tpl
    http://schemas.ogf.org/occi/infrastructure#resource_tpl
  )

  CONTEXT_MIXINS = %w(
    http://schemas.openstack.org/instance/credentials#public_key
    http://schemas.openstack.org/compute/instance#user_data
  )

  def run(options, args = [])
    mixins = []
    mixins += INFRA_MIXINS if %w(infra all).include?(options[:mixins])
    mixins += CONTEXT_MIXINS if %w(context all).include?(options[:mixins])
    mixins -= options[:optional] if options[:optional]

    begin
      Timeout::timeout(options[:timeout]) {
        mixins.each { |mixin| fail "#{mixin.inspect} is missing" unless client(options).model.get_by_id(mixin, true) }
      }
    rescue => ex
      puts "MIXINS CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    end

    puts 'MIXINS OK - All specified OCCI mixins were found'
  end
end
