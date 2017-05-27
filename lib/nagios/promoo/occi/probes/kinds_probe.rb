# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Occi
      module Probes
        class KindsProbe < Nagios::Promoo::Occi::Probes::BaseProbe
          class << self
            def description
              ['kinds', 'Run a probe checking for mandatory OCCI kind definitions']
            end

            def options
              [
                [
                  :kinds,
                  {
                    type: :string, enum: %w(core infra all), default: 'all',
                    desc: 'Collection of mandatory kinds to check'
                  }
                ],
                [
                  :optional,
                  {
                    type: :array, default: [],
                    desc: 'Identifiers of optional kinds (optional by force)'
                  }
                ],
                [
                  :check_location,
                  {
                    type: :boolean, default: false,
                    desc: 'Verify declared REST locations for INFRA resources'
                  }
                ]
              ]
            end

            def declaration
              'kinds'
            end

            def runnable?
              true
            end
          end

          CORE_KINDS = %w(
            http://schemas.ogf.org/occi/core#entity
            http://schemas.ogf.org/occi/core#resource
            http://schemas.ogf.org/occi/core#link
          ).freeze

          INFRA_KINDS = %w(
            http://schemas.ogf.org/occi/infrastructure#compute
            http://schemas.ogf.org/occi/infrastructure#storage
            http://schemas.ogf.org/occi/infrastructure#network
            http://schemas.ogf.org/occi/infrastructure#storagelink
            http://schemas.ogf.org/occi/infrastructure#networkinterface
          ).freeze

          def run(_args = [])
            kinds = []
            kinds += CORE_KINDS if %w(core all).include?(options[:kinds])
            kinds += INFRA_KINDS if %w(infra all).include?(options[:kinds])
            kinds -= options[:optional] if options[:optional]

            Timeout.timeout(options[:timeout]) do
              kinds.each do |kind|
                raise "#{kind.inspect} is missing" unless client.model.get_by_id(kind, true)
                next unless options[:check_location] && INFRA_KINDS.include?(kind)

                # Make sure declared locations are actually available as REST
                # endpoints. Failure will raise an exception, no need to do
                # anything here. To keep requirements reasonable, only INFRA
                # kinds are considered relevant for this part of the check.
                begin
                  client.list(kind)
                rescue => err
                  raise "Failed to verify declared REST location for #{kind.inspect} (#{err.message})"
                end
              end
            end

            puts 'KINDS OK - All specified OCCI kinds were found'
          rescue => ex
            puts "KINDS CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          end
        end
      end
    end
  end
end
