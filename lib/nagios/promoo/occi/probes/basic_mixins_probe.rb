class Nagios::Promoo::Occi::Probes::BasicMixinsProbe
  class << self
    def description
      ['basic-mixins', 'Run a probe checking for mandatory OCCI mixin definitions']
    end

    def options
      [
        [:mixins, { type: :string, enum: %w(infra context all), default: 'all', desc: 'Collection of mandatory mixins to check' }],
        [:optional, { type: :array, default: [], desc: 'Identifiers of optional mixins (optional by force)' }]
      ]
    end

    def declaration
      "basic_mixins"
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

  def run(args = [])
    puts 'Hunky-dory!'
  end
end
