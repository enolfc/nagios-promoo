class Nagios::Promoo::Occi::Probes::BaseProbe
  class << self
    def runnable?; false; end
  end

  def client(options)
    @client ||= Occi::Api::Client::ClientHttp.new({
      :endpoint => options[:endpoint],
      :auth => {
        :type               => options[:auth].gsub('-voms', ''),
        :user_cert          => options[:token].gsub('file://', ''),
        :user_cert_password => nil,
        :ca_path            => options[:ca_path],
        :voms               => options[:auth] == 'x509-voms' ? true : false
      },
      :log => {
        :level  => options[:debug] ? Occi::Api::Log::DEBUG : Occi::Api::Log::ERROR,
        :logger => nil,
        :out => '/dev/null',
      }
    })
  end
end
