# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Occi::Probes::ComputeProbe < Nagios::Promoo::Occi::Probes::BaseProbe
  class << self
    def description
      ['compute', 'Run a probe creating a compute instance via OCCI']
    end

    def options
      [
        [:mpuri, { type: :string, required: true, desc: 'AppDB MPURI referencing a virtual appliance' }],
        [:cache_expiration, { type: :numeric, default: 7200, desc: 'AppDB cache expiration (in seconds)' }],
        [:compute_timeout, { type: :numeric, default: 359, desc: 'Timeout for compute instantiation (in seconds)' }],
        [:appdb_timeout, { type: :numeric, default: 359, desc: 'Timeout for AppDB queries (in seconds)' }],
        [:cleanup, { type: :boolean, default: true, desc: 'Perform clean-up before launching a new instance' }],
      ]
    end

    def declaration
      "compute"
    end

    def runnable?; true; end
  end

  COMPUTE_NAME_PREFIX = "sam-nagios-promoo"
  CACHE_DIR = '/tmp/nagios-promoo_cache'
  APPDB_PROXY_URL = 'https://appdb.egi.eu/api/proxy'
  APPDB_REQUEST_FORM = 'version=1.0&resource=broker&data=%3Cappdb%3Abroker%20xmlns%3Axs%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%22%20xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22%20xmlns%3Aappdb%3D%22http%3A%2F%2Fappdb.egi.eu%2Fapi%2F1.0%2Fappdb%22%3E%3Cappdb%3Arequest%20id%3D%22vaproviders%22%20method%3D%22GET%22%20resource%3D%22va_providers%22%3E%3Cappdb%3Aparam%20name%3D%22listmode%22%3Edetails%3C%2Fappdb%3Aparam%3E%3C%2Fappdb%3Arequest%3E%3C%2Fappdb%3Abroker%3E'

  def run(options, args = [])
    fail "Timeout (#{options[:timeout]}) must be higher than compute-timeout (#{options[:compute_timeout]}) "\
         "+ appdb-timeout (#{options[:appdb_timeout]})" if options[:timeout] <= (options[:compute_timeout] + options[:appdb_timeout])

    link = begin
             Timeout::timeout(options[:timeout]) { compute_create(*appdb_information(options), options) }
           rescue Timeout::Error => ex
             puts "COMPUTE CRITICAL - Probe execution timed out [#{options[:timeout]}s]"
             exit 2
           end

    puts "COMPUTE OK - Instance #{link.inspect} created & cleaned up"
  end

  private

  def compute_create(os_tpl, resource_tpl, options)
    link = nil

    begin
      2.times { client(options).delete('compute') } if options[:cleanup]
      compute = client(options).get_resource('compute')
      compute.title = compute.hostname = "#{COMPUTE_NAME_PREFIX}-#{Time.now.to_i}"

      compute.mixins << get_mixin(os_tpl, 'os_tpl', options)
      compute.mixins << get_mixin(resource_tpl, 'resource_tpl', options)

      link = client(options).create(compute)
      wait4compute(link, options)
    rescue => ex
      puts "COMPUTE CRITICAL - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 2
    ensure
      begin
        client(options).delete(link) unless link.blank?
      rescue => ex
        ## ignoring
      end
    end

    link
  end

  def get_mixin(term, type, options)
    mxn = client(options).get_mixin(term, type, true)
    fail "Mixin #{term.inspect} of type #{type.inspect} not found at the site" unless mxn
    mxn
  end

  def wait4compute(link, options)
    state = 'inactive'

    begin
      Timeout::timeout(options[:compute_timeout]) {
        while state != 'active' do
          state = client(options).describe(link).first.state
          fail 'Failed to deploy an instance (resulting OCCI state was "error")' if state == 'error'
          sleep 5
        end
      }
    rescue Timeout::Error => ex
      puts "COMPUTE WARNING - Execution timed out while waiting for the instance to become active [#{options[:compute_timeout]}s]"
      exit 1
    end
  end

  def appdb_information(options)
    begin
      Timeout::timeout(options[:appdb_timeout]) {
        [appdb_appliance(options), appdb_smallest_size(options)]
      }
    rescue => ex
      puts "COMPUTE UNKNOWN - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 3
    end
  end

  def appdb_appliance(options)
    appliance = appdb_provider(options)['image'].select do |image|
      image['mp_uri'] && (normalize_mpuri(image['mp_uri']) == normalize_mpuri(options[:mpuri]))
    end.first
    fail "No such appliance is published in AppDB" if appliance.blank?

    appliance['va_provider_image_id'].split('#').last
  end

  def appdb_smallest_size(options)
    sizes = []
    appdb_provider(options)['template'].each do |template|
      sizes << [
        template['resource_name'].split('#').last,
        template['main_memory_size'].to_i + template['physical_cpus'].to_i
      ]
    end
    fail "No appliance sizes available in AppDB" if sizes.blank?
    sizes.sort! { |x,y| x.last <=> y.last }

    sizes.first.first
  end

  def appdb_provider(options)
    return @provider if @provider

    parsed_response = cache_fetch('appdb-sites', options[:cache_expiration]) do
                        response = HTTParty.post(APPDB_PROXY_URL, { :body => APPDB_REQUEST_FORM })
                        fail "Could not get appliance"\
                             "details from AppDB [#{response.code}]" unless response.success?
                        response.parsed_response
                      end

    @provider = parsed_response['broker']['reply']['appdb']['provider'].select do |prov|
      prov['endpoint_url'] && (prov['endpoint_url'].chomp('/') == options[:endpoint].chomp('/'))
    end.first
    fail "Could not locate site by endpoint #{options[:endpoint]} in AppDB" unless @provider

    @provider
  end

  def cache_fetch(key, expiration = 3600)
    fail 'You have to provide a block!' unless block_given?
    FileUtils.mkdir_p CACHE_DIR
    filename = File.join(CACHE_DIR, key)

    if cache_valid?(filename, expiration)
      File.open(filename, 'r') { |file| JSON.parse file.read }
    else
      data = yield
      File.open(filename, 'w') { |file| file.write JSON.pretty_generate(data) }
      data
    end
  end

  def cache_valid?(filename, expiration)
    File.exists?(filename) && ((Time.now - expiration) < File.stat(filename).mtime)
  end

  def normalize_mpuri(mpuri)
    mpuri.gsub(/\/+$/, '').gsub(/:\d+$/, '')
  end
end
