class Nagios::Promoo::Opennebula::Probes::BaseProbe
  class << self
    def runnable?; false; end
  end

  attr_reader :options

  def initialize(options)
    @options = options
  end

  def client
    return @_client if @_client

    token = options[:token].start_with?('file://') ? File.read(options[:token].gsub('file://', '')) : options[:token]
    @_client = OpenNebula::Client.new("#{token}", options[:endpoint])
  end
end
