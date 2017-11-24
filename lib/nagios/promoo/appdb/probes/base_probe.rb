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

          APPDB_IS_URL = 'http://is.marie.hellasgrid.gr/graphql'.freeze
          DEFAULT_HEADERS = { 'Content-Type' => 'application/json' }.freeze
          GQL_SIZES_BY_ENDPOINT = %|
{
  siteServiceTemplates(
    filter: { service: { endpointURL: { eq: "$$ENDPOINT$$" } } }, limit: 1000
  ) {
    items { resourceID }
  }
}
|.freeze
          GQL_APPLIANCES_BY_ENDPOINT = %|
{
  siteServiceImages(
    filter: { imageVoVmiInstanceVO: { eq: "$$VO$$" }, service: { endpointURL: { eq: "$$ENDPOINT$$" } } }, limit: 1000
  ) {
    items { applicationEnvironmentRepository applicationEnvironmentAppVersion }
  }
}
|.freeze

          attr_reader :options, :endpoint

          def initialize(options)
            @options = options
            @endpoint = options[:endpoint].gsub(%r{/+$}, '')
          end

          def sizes_by_endpoint
            return @_sizes if @_sizes

            query = GQL_SIZES_BY_ENDPOINT.gsub('$$ENDPOINT$$', endpoint)
            @_sizes = make(query)['data']['siteServiceTemplates']['items']
            raise "Could not locate sizes from endpoint #{endpoint.inspect} in AppDB" unless @_sizes

            @_sizes
          end

          def appliances_by_endpoint(vo)
            return @_appliances if @_appliances

            query = GQL_APPLIANCES_BY_ENDPOINT.gsub('$$ENDPOINT$$', endpoint).gsub('$$VO$$', vo)
            @_appliances = make(query)['data']['siteServiceImages']['items']
            raise "Could not locate appliances from endpoint #{endpoint.inspect} in AppDB" unless @_appliances

            @_appliances
          end

          private

          def make(query)
            response = HTTParty.post(APPDB_IS_URL, body: { query: query }.to_json, headers: DEFAULT_HEADERS)
            raise "#{query.inspect} failed to get data from AppDB [HTTP #{response.code}]" unless response.success?

            response.parsed_response
          end
        end
      end
    end
  end
end
