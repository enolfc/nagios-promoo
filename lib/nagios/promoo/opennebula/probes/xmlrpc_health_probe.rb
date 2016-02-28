class Nagios::Promoo::Opennebula::Probes::XmlrpcHealthProbe
  class << self
    def description
      ['xmlrpc-health', 'Run a probe checking on OpenNebula\'s XML RPC service']
    end

    def options
      []
    end

    def declaration
      "xmlrpc_health"
    end

    def runnable_probe?; true; end
  end

  def run(args = [])
    puts 'Hunky-dory!'
  end
end
