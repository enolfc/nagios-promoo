# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

module Nagios
  module Promoo
    module Occi
      module Probes
        # Probe for checking compute instantiation via OCCI.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class ComputeProbe < Nagios::Promoo::Occi::Probes::BaseProbe
          class << self
            def description
              ['compute', 'Run a probe creating a compute instance via OCCI']
            end

            def options
              [
                [:mpuri, { type: :string, required: true, desc: 'AppDB MPURI referencing a virtual appliance' }],
                [
                  :with_storage,
                  {
                    type: :boolean, default: false,
                    desc: 'Run test attaching a storage instance to compute instance'
                  }
                ],
                [:cache_expiration, { type: :numeric, default: 7200, desc: 'AppDB cache expiration (in seconds)' }],
                [:cleanup, { type: :boolean, default: true, desc: 'Perform clean-up before launching a new instance' }]
              ]
            end

            def declaration
              'compute'
            end

            def runnable?
              true
            end
          end

          READY_STATES = %w[active online].freeze
          NONREADY_STATES = %w[inactive offline].freeze
          ERROR_STATES = %w[error].freeze

          CPU_SUM_WEIGHT = 1000
          COMPUTE_NAME_PREFIX = 'sam-nagios-promoo'.freeze
          DEFAULT_STORAGE_SIZE = 1 # GB
          APPDB_PROXY_URL = 'https://appdb.egi.eu/api/proxy'.freeze
          APPDB_REQUEST_FORM = 'version=1.0&resource=broker&data=%3Cappdb%3Abroker%20xmlns' \
                               '%3Axs%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%22%20' \
                               'xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXML' \
                               'Schema-instance%22%20xmlns%3Aappdb%3D%22http%3A%2F%2F' \
                               'appdb.egi.eu%2Fapi%2F1.0%2Fappdb%22%3E%3Cappdb%3Arequest%20' \
                               'id%3D%22vaproviders%22%20method%3D%22GET%22%20resource%3D%22' \
                               'va_providers%22%3E%3Cappdb%3Aparam%20name%3D%22listmode%22%3E' \
                               'details%3C%2Fappdb%3Aparam%3E%3C%2Fappdb%3Arequest%3E%3C%2Fappdb%3Abroker%3E'.freeze

          def run(_args = [])
            @_links = {}

            Timeout.timeout(options[:timeout]) { compute_provision }
            puts "COMPUTE OK - Instance(s) #{@_links[:compute].inspect} created & cleaned up"
          rescue Timeout::Error
            puts "COMPUTE CRITICAL - Probe execution timed out [#{options[:timeout]}s]"
            exit 2
          end

          private

          def compute_provision
            compute_create

            if options[:with_storage]
              storage_create
              link_instances
            end
          rescue => ex
            puts "COMPUTE CRITICAL - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 2
          ensure
            begin
              mandatory_cleanup @_links
            rescue => ex
              puts "COMPUTE CRITICAL - #{ex.message}"
              puts ex.backtrace if options[:debug]
              exit 2
            end
          end

          def compute_create
            client.delete('compute') if options[:cleanup]

            compute = client.get_resource('compute')
            compute.title = compute.hostname = "#{COMPUTE_NAME_PREFIX}-#{Time.now.to_i}"

            os_tpl, resource_tpl = appdb_information
            compute.mixins << get_mixin(os_tpl, 'os_tpl')
            compute.mixins << get_mixin(resource_tpl, 'resource_tpl')

            @_links[:compute] = client.create compute
            wait4ready @_links[:compute]
          end

          def storage_create
            client.delete('storage') if options[:cleanup]

            storage = client.get_resource('storage')
            storage.title = "#{COMPUTE_NAME_PREFIX}-block-#{Time.now.to_i}"
            storage.size = DEFAULT_STORAGE_SIZE # GB

            @_links[:storage] = client.create storage
            wait4ready @_links[:storage]
          end

          def link_instances
            slink = client.get_link('storagelink')
            slink.source = @_links[:compute]
            slink.target = @_links[:storage]

            @_links[:storagelink] = client.create slink
            wait4ready @_links[:storagelink]
          end

          def mandatory_cleanup(links)
            mandatory_cleanup_part links[:storagelink], true
            mandatory_cleanup_part links[:storage], false
            mandatory_cleanup_part links[:compute], false
          end

          def mandatory_cleanup_part(link, wait4inactive)
            return if link.blank?
            client.delete link
            wait4inactive(link) if wait4inactive
          end

          def get_mixin(term, type)
            mxn = client.get_mixin(term, type, true)
            raise "Mixin #{term.inspect} of type #{type.inspect} not found at the site" unless mxn
            mxn
          end

          def wait4ready(link)
            state = nil

            until READY_STATES.include?(state)
              state = client.describe(link).first.state
              raise "Provisioning failure on #{link.inspect}" if ERROR_STATES.include?(state)
              sleep 5
            end
          end

          def wait4inactive(link)
            state = nil

            until NONREADY_STATES.include?(state)
              state = client.describe(link).first.state
              raise "De-provisioning failure on #{link.inspect}" if ERROR_STATES.include?(state)
              sleep 5
            end
          end

          def appdb_information
            [appdb_appliance, appdb_smallest_size]
          rescue => ex
            puts "COMPUTE UNKNOWN - #{ex.message}"
            puts ex.backtrace if options[:debug]
            exit 3
          end

          def appdb_appliance
            appliances = [appdb_provider['provider:image']].flatten.compact
            appliances.delete_if { |appl| appl['mp_uri'].blank? }

            appliance = appliances.detect do |appl|
              normalize_mpuri(appl['mp_uri']) == normalize_mpuri(options[:mpuri])
            end
            if appliance.blank?
              raise 'Site does not have an appliance with MPURI '\
                   "#{normalize_mpuri(options[:mpuri]).inspect} published in AppDB"
            end

            appliance['va_provider_image_id'].split('#').last
          end

          def appdb_smallest_size
            sizes = []
            templates = [appdb_provider['provider:template']].flatten.compact

            templates.each do |template|
              sizes << [
                template['provider_template:resource_name'].split('#').last,
                template['provider_template:main_memory_size'].to_i \
                + (template['provider_template:physical_cpus'].to_i * CPU_SUM_WEIGHT)
              ]
            end
            raise 'No appliance sizes available in AppDB' if sizes.blank?

            sizes.sort! { |x, y| x.last <=> y.last }
            sizes.first.first
          end

          def appdb_provider
            return @_provider if @_provider

            @_provider = appdb_providers.detect do |prov|
              prov['provider:endpoint_url'].chomp('/') == options[:endpoint].chomp('/')
            end
            raise "Could not locate site by endpoint #{options[:endpoint].inspect} in AppDB" unless @_provider

            @_provider
          end

          def appdb_providers
            parsed_response = cache_fetch('appdb-sites', options[:cache_expiration]) do
              response = HTTParty.post(APPDB_PROXY_URL, body: APPDB_REQUEST_FORM)
              raise "Could not get appliance details from AppDB [#{response.code}]" unless response.success?
              raise 'Response from AppDB has unexpected structure' unless valid_response?(response.parsed_response)

              response.parsed_response
            end

            providers = parsed_response['appdb:broker']['appdb:reply']\
                                       ['appdb:appdb']['virtualization:provider']
            providers.delete_if { |prov| prov['provider:endpoint_url'].blank? }
          end

          def normalize_mpuri(mpuri)
            mpuri.gsub(%r{/+$}, '').gsub(/:\d+$/, '')
          end

          def valid_response?(response)
            response['appdb:broker'] \
            && response['appdb:broker']['appdb:reply'] \
            && response['appdb:broker']['appdb:reply']['appdb:appdb'] \
            && response['appdb:broker']['appdb:reply']['appdb:appdb']['virtualization:provider']
          end

          include Nagios::Promoo::Utils::Cache
        end
      end
    end
  end
end
