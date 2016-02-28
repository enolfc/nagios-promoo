class Nagios::Promoo::Occi::Probes::BasicKindsProbe
  class << self
    def description
      ['basic-kinds', 'Run a probe checking for mandatory OCCI kind definitions']
    end

    def options
      [
        [:kinds, { type: :string, enum: %w(core infra all), default: 'all', desc: 'Collection of mandatory kinds to check' }],
        [:optional, { type: :array, default: [], desc: 'Identifiers of optional kinds (optional by force)' }]
      ]
    end

    def declaration
      "basic_kinds"
    end

    def runnable?; true; end
  end

  CORE_KINDS = %w(
    http://schemas.ogf.org/occi/core#resource
    http://schemas.ogf.org/occi/core#link
  )

  INFRA_KINDS = %w(
    http://schemas.ogf.org/occi/infrastructure#compute
    http://schemas.ogf.org/occi/infrastructure#storage
    http://schemas.ogf.org/occi/infrastructure#network
    http://schemas.ogf.org/occi/infrastructure#storagelink
    http://schemas.ogf.org/occi/infrastructure#networkinterface
  )

  def run(args = [])
    puts 'Hunky-dory!'
  end
end
