# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Appdb::Probes::SizesProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
  class << self
    def description
      ['sizes', 'Run a probe checking size/flavor/resource templates in AppDB']
    end

    def options
      []
    end

    def declaration
      "sizes"
    end

    def runnable?; true; end
  end

  def run(args = [])
    @_count = 0

    Timeout::timeout(options[:timeout]) { check_sizes }

    if @_count < 1
      puts "SIZES CRITICAL - No size/flavor/resource templates found in AppDB"
      exit 2
    end

    puts "SIZES OK - Found #{@_count} size/flavor/resource templates in AppDB"
  rescue => ex
    puts "SIZES UNKNOWN - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 3
  end

  private

  def check_sizes
    @_count = [appdb_provider['provider:template']].flatten.compact.count
  end
end
