# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Appdb::Probes::AppliancesProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
  class << self
    def description
      ['appliances', 'Run a probe checking appliances in AppDB']
    end

    def options
      []
    end

    def declaration
      "appliances"
    end

    def runnable?; true; end
  end

  def run(args = [])
    count = 0
    begin
      count = Timeout::timeout(options[:timeout]) { check_appliances }
    rescue => ex
      puts "APPLIANCES UNKNOWN - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 3
    end

    if count < 1
      puts "APPLIANCES CRITICAL - No appliances found in AppDB" 
      exit 2
    end

    puts "APPLIANCES OK - Found #{count} appliances in AppDB"
  end

  private

  def check_appliances
    [appdb_provider['provider:image']].flatten.compact.count
  end
end
