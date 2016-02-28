class Nagios::Promoo::Opennebula::Probes::BaseProbe
  class << self
    def runnable?; false; end
  end

  def client(options)
    return @client if @client

    token = options[:token].start_with?('file://') ? File.read(options[:token].gsub('file://', '')) : options[:token]
    @client = OpenNebula::Client.new("#{token}", options[:endpoint])
  end
end
