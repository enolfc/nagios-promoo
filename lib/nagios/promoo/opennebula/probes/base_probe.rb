module Nagios
  module Promoo
    module Opennebula
      module Probes
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
            return @_client if @_client

            token = token_file? ? read_token : options[:token]
            @_client = OpenNebula::Client.new(token.to_s, options[:endpoint])
          end

          private

          def token_file?
            options[:token].start_with?('file://')
          end

          def read_token
            File.read(options[:token].gsub('file://', ''))
          end
        end
      end
    end
  end
end
