# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Appdb::Probes::SizesProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
  class << self
    def description
      ['sizes', 'Run a probe checking size templates in AppDB']
    end

    def options
      []
    end

    def declaration
      "sizes"
    end

    def runnable?; true; end
  end

  def run(options, args = [])
    count = nil
    begin
      count = Timeout::timeout(options[:timeout]) { check_sizes(options) }
      fail "No size templates found in AppDB" if count < 1
    rescue => ex
      puts "SIZES CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    end

    puts "SIZES OK - Found #{count} size templates in AppDB"
  end

  private

  def check_sizes(options)
    (appdb_provider(options)['template'] || []).count
  end
end
