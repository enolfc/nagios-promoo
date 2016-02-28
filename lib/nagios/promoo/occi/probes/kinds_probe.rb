# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Occi::Probes::KindsProbe < Nagios::Promoo::Occi::Probes::BaseProbe
  class << self
    def description
      ['kinds', 'Run a probe checking for mandatory OCCI kind definitions']
    end

    def options
      [
        [:kinds, { type: :string, enum: %w(core infra all), default: 'all', desc: 'Collection of mandatory kinds to check' }],
        [:optional, { type: :array, default: [], desc: 'Identifiers of optional kinds (optional by force)' }]
      ]
    end

    def declaration
      "kinds"
    end

    def runnable?; true; end
  end

  CORE_KINDS = %w(
    http://schemas.ogf.org/occi/core#entity
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

  def run(options, args = [])
    kinds = []
    kinds += CORE_KINDS if %w(core all).include?(options[:kinds])
    kinds += INFRA_KINDS if %w(infra all).include?(options[:kinds])
    kinds -= options[:optional] if options[:optional]

    begin
      kinds.each { |kind| fail "#{kind.inspect} is missing" unless client(options).model.get_by_id(kind, true) }
    rescue => ex
      puts "KINDS CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    end

    puts 'KINDS OK - All specified OCCI kinds were found'
  end
end
