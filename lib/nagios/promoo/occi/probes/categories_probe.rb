# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')
require File.join(File.dirname(__FILE__), 'kinds_probe')
require File.join(File.dirname(__FILE__), 'mixins_probe')

class Nagios::Promoo::Occi::Probes::CategoriesProbe < Nagios::Promoo::Occi::Probes::BaseProbe
  class << self
    def description
      ['categories', 'Run a probe checking for mandatory OCCI category definitions']
    end

    def options
      [
        [:optional, { type: :array, default: [], desc: 'Identifiers of optional categories (optional by force)' }],
        [:check_location, { type: :boolean, default: false, desc: 'Verify declared REST locations for INFRA resources' }],
      ]
    end

    def declaration
      "categories"
    end

    def runnable?; true; end
  end

  def run(options, args = [])
    categories = all_categories
    categories -= options[:optional] if options[:optional]

    begin
      Timeout::timeout(options[:timeout]) do
        categories.each do |cat|
          fail "#{cat.inspect} is missing" unless client(options).model.get_by_id(cat, true)
          next unless options[:check_location] && Nagios::Promoo::Occi::Probes::KindsProbe::INFRA_KINDS.include?(cat)

          # Make sure declared locations are actually available as REST
          # endpoints. Failure will raise an exception, no need to do
          # anything here. To keep requirements reasonable, only INFRA
          # kinds are considered relevant for this part of the check.
          begin
            client(options).list(cat)
          rescue => err
            fail "Failed to verify declared REST location for #{cat.inspect} (#{err.message})"
          end
        end
      end
    rescue => ex
      puts "CATEGORIES CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    end

    puts 'CATEGORIES OK - All specified OCCI categories were found'
  end

  private

  def all_categories
    Nagios::Promoo::Occi::Probes::KindsProbe::CORE_KINDS + Nagios::Promoo::Occi::Probes::KindsProbe::INFRA_KINDS \
    + Nagios::Promoo::Occi::Probes::MixinsProbe::INFRA_MIXINS + Nagios::Promoo::Occi::Probes::MixinsProbe::CONTEXT_MIXINS
  end
end
