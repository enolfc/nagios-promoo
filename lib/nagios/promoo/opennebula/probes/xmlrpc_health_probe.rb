# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Opennebula::Probes::XmlrpcHealthProbe < Nagios::Promoo::Opennebula::Probes::BaseProbe
  class << self
    def description
      ['xmlrpc-health', 'Run a probe checking OpenNebula\'s XML RPC service']
    end

    def options
      []
    end

    def declaration
      "xmlrpc_health"
    end

    def runnable?; true; end
  end

  def run(args = [])
    rc = Timeout::timeout(options[:timeout]) { client.get_version }
    fail rc.message if OpenNebula.is_error?(rc)

    puts "XMLRPC OK - OpenNebula #{rc} daemon is up and running"
  rescue => ex
    puts "XMLRPC CRITICAL - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 2
  end
end
