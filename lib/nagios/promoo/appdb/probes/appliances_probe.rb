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

  def run(options, args = [])
    count = nil
    begin
      count = Timeout::timeout(options[:timeout]) { check_appliances(options) }
      fail "No appliances found in AppDB" if count < 1
    rescue => ex
      puts "APPLIANCES CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    end

    puts "APPLIANCES OK - Found #{count} appliances in AppDB"
  end

  private

  def check_appliances(options)
    (appdb_provider(options)['image'] || []).count
  end
end
