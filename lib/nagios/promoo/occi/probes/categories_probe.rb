# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')
require File.join(File.dirname(__FILE__), 'kinds_probe')
require File.join(File.dirname(__FILE__), 'mixins_probe')

module Nagios
  module Promoo
    module Occi
      module Probes
        # Probe for checking OCCI categories declared by endpoints.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class CategoriesProbe < Nagios::Promoo::Occi::Probes::BaseProbe
          class << self
            def description
              ['categories', 'Run a probe checking for mandatory OCCI category definitions']
            end

            def options
              [
                [
                  :optional,
                  {
                    type: :array, default: [],
                    desc: 'Identifiers of optional categories (optional by force)'
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
              'categories'
            end

            def runnable?
              true
            end
          end

          def run(_args = [])
            categories = all_categories
            categories -= options[:optional] if options[:optional]

            Timeout.timeout(options[:timeout]) do
              categories.each do |cat|
                raise "#{cat.inspect} is missing" unless client.model.get_by_id(cat, true)
                next unless options[:check_location] && infra_kinds.include?(cat)

                # Make sure declared locations are actually available as REST
                # endpoints. Failure will raise an exception, no need to do
                # anything here. To keep requirements reasonable, only INFRA
                # kinds are considered relevant for this part of the check.
                begin
                  client.list(cat)
                rescue => ex
                  raise "Failed to verify declared REST location for #{cat.inspect} (#{ex.message})"
                end
              end
            end

            puts 'CATEGORIES OK - All specified OCCI categories were found'
          rescue => ex
            puts "CATEGORIES CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          end

          private

          def core_kinds
            Nagios::Promoo::Occi::Probes::KindsProbe::CORE_KINDS
          end

          def infra_kinds
            Nagios::Promoo::Occi::Probes::KindsProbe::INFRA_KINDS
          end

          def infra_mixins
            Nagios::Promoo::Occi::Probes::MixinsProbe::INFRA_MIXINS
          end

          def context_mixins
            Nagios::Promoo::Occi::Probes::MixinsProbe::CONTEXT_MIXINS
          end

          def all_categories
            %i[core_kinds infra_kinds infra_mixins context_mixins].reduce([]) do |memo, elm|
              memo.concat send(elm)
            end
          end
        end
      end
    end
  end
end
