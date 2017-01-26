class Nagios::Promoo::Appdb::Probes::BaseProbe
  class << self
    def runnable?; false; end
  end

  APPDB_PROXY_URL = 'https://appdb.egi.eu/api/proxy'
  APPDB_REQUEST_FORM = 'version=1.0&resource=broker&data=%3Cappdb%3Abroker%20xmlns%3Axs%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%22%20xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22%20xmlns%3Aappdb%3D%22http%3A%2F%2Fappdb.egi.eu%2Fapi%2F1.0%2Fappdb%22%3E%3Cappdb%3Arequest%20id%3D%22vaproviders%22%20method%3D%22GET%22%20resource%3D%22va_providers%22%3E%3Cappdb%3Aparam%20name%3D%22listmode%22%3Edetails%3C%2Fappdb%3Aparam%3E%3C%2Fappdb%3Arequest%3E%3C%2Fappdb%3Abroker%3E'

  attr_reader :options

  def initialize(options)
    @options = options
  end

  def appdb_provider
    return @_provider if @_provider

    response = HTTParty.post(APPDB_PROXY_URL, { :body => APPDB_REQUEST_FORM })
    fail "Could not get site"\
         "details from AppDB [HTTP #{response.code}]" unless response.success?
    fail "Response from AppDB has unexpected structure" unless valid_response?(response.parsed_response)

    providers = response.parsed_response['appdb:broker']['appdb:reply']['appdb:appdb']['virtualization:provider']
    providers.delete_if { |prov| prov['provider:endpoint_url'].blank? }

    @_provider = providers.select do |prov|
                   prov['provider:endpoint_url'].chomp('/') == options[:endpoint].chomp('/')
                 end.first
    fail "Could not locate site by endpoint #{options[:endpoint].inspect} in AppDB" unless @_provider

    @_provider
  end

  private

  def valid_response?(response)
    response['appdb:broker'] \
    && response['appdb:broker']['appdb:reply'] \
    && response['appdb:broker']['appdb:reply']['appdb:appdb'] \
    && response['appdb:broker']['appdb:reply']['appdb:appdb']['virtualization:provider']
  end
end
