module Nagios
  module Promoo
    module Occi
      module Probes
        # Base probe for all OCCI-related probes.
        #
        # @author Boris Parak <parak@cesnet.cz>
        class BaseProbe
          class << self
            def runnable?
              false
            end
          end

          attr_reader :options

          def initialize(options)
            @options = options
          end

          def client
            @_client ||= ::Occi::Api::Client::ClientHttp.new(
              endpoint: options[:endpoint],
              auth: {
                type: options[:auth].gsub('-voms', ''),
                user_cert: options[:token].gsub('file://', ''),
                user_cert_password: nil,
                token: options[:token],
                ca_path: options[:ca_path],
                voms: options[:auth] == 'x509-voms' ? true : false
              },
              log: {
                level: options[:debug] ? ::Occi::Api::Log::DEBUG : ::Occi::Api::Log::ERROR,
                logger: nil,
                out: '/dev/null'
              }
            )
          end
        end
      end
    end
  end
end
