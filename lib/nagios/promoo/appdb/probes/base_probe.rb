module Nagios
  module Promoo
    module Appdb
      module Probes
        # Base probe class for all AppDB-related probes.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class BaseProbe
          class << self
            def runnable?
              false
            end
          end

          APPDB_PROVIDERS_URL = 'https://appdb.egi.eu/rest/1.0/va_providers?listmode=details'.freeze

          attr_reader :options

          def initialize(options)
            @options = options
          end

          def appdb_provider
            return @_provider if @_provider

            @_provider = appdb_providers.detect do |prov|
              prov['provider:endpoint_url'].chomp('/') == options[:endpoint].chomp('/')
            end
            raise "Could not locate site by endpoint #{options[:endpoint].inspect} in AppDB" unless @_provider

            @_provider
          end

          private

          def appdb_providers
            response = HTTParty.get(APPDB_PROVIDERS_URL)
            raise "Could not get site details from AppDB [HTTP #{response.code}]" unless response.success?
            raise 'Response from AppDB has unexpected structure' unless valid_response?(response.parsed_response)

            providers = response.parsed_response['appdb:appdb']['virtualization:provider']
            providers.delete_if { |prov| prov['provider:endpoint_url'].blank? }
          end

          def valid_response?(response)
            response['appdb:appdb'] \
            && response['appdb:appdb']['virtualization:provider']
          end
        end
      end
    end
  end
end
