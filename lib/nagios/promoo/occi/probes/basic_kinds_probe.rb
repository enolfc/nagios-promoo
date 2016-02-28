class Nagios::Promoo::Occi::Probes::BasicKindsProbe
  class << self
    def description
      ['basic-kinds', 'Run a probe checking for the presence of mandatory OCCI kind definitions']
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
  end

  def run(args = [])
    puts 'Hunky-dory!'
  end
end
