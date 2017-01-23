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
        [:with_storage, { type: :boolean, default: false, desc: 'Run test attaching a storage instance to compute instance' }],
        [:cache_expiration, { type: :numeric, default: 7200, desc: 'AppDB cache expiration (in seconds)' }],
        [:cleanup, { type: :boolean, default: true, desc: 'Perform clean-up before launching a new instance' }],
      ]
    end

    def declaration
      "compute"
    end

    def runnable?; true; end
  end

  READY_STATES = %w(active online).freeze
  NONREADY_STATES = %w(inactive offline).freeze
  ERROR_STATES = %w(error).freeze

  CPU_SUM_WEIGHT = 1000
  COMPUTE_NAME_PREFIX = "sam-nagios-promoo"
  DEFAULT_STORAGE_SIZE = 1 # GB
  APPDB_PROXY_URL = 'https://appdb.egi.eu/api/proxy'
  APPDB_REQUEST_FORM = 'version=1.0&resource=broker&data=%3Cappdb%3Abroker%20xmlns%3Axs%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%22%20xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22%20xmlns%3Aappdb%3D%22http%3A%2F%2Fappdb.egi.eu%2Fapi%2F1.0%2Fappdb%22%3E%3Cappdb%3Arequest%20id%3D%22vaproviders%22%20method%3D%22GET%22%20resource%3D%22va_providers%22%3E%3Cappdb%3Aparam%20name%3D%22listmode%22%3Edetails%3C%2Fappdb%3Aparam%3E%3C%2Fappdb%3Arequest%3E%3C%2Fappdb%3Abroker%3E'

  def run(options, args = [])
    links = begin
              Timeout::timeout(options[:timeout]) { compute_provision(options) }
            rescue Timeout::Error => ex
              puts "COMPUTE CRITICAL - Probe execution timed out [#{options[:timeout]}s]"
              exit 2
            end

    puts "COMPUTE OK - Instance(s) #{links[:compute].inspect} created & cleaned up"
  end

  private

  def compute_provision(options)
    links = {}

    compute_link = compute_create(options)
    links[:compute] = compute_link
    wait4ready(compute_link, options)

    if options[:with_storage]
      storage_link = storage_create(options)
      links[:storage] = storage_link
      wait4ready(storage_link, options)

      slink = link_instances(compute_link, storage_link, options)
      links[:storagelink] = slink
      wait4ready(slink, options)
    end

    links
  rescue => ex
    puts "COMPUTE CRITICAL - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 2
  ensure
    mandatory_cleanup links, options
  end

  def compute_create(options)
    client(options).delete('compute') if options[:cleanup]

    compute = client(options).get_resource('compute')
    compute.title = compute.hostname = "#{COMPUTE_NAME_PREFIX}-#{Time.now.to_i}"

    os_tpl, resource_tpl = appdb_information(options)
    compute.mixins << get_mixin(os_tpl, 'os_tpl', options)
    compute.mixins << get_mixin(resource_tpl, 'resource_tpl', options)

    client(options).create compute
  end

  def storage_create(options)
    client(options).delete('storage') if options[:cleanup]

    storage = client(options).get_resource('storage')
    storage.title = "#{COMPUTE_NAME_PREFIX}-block-#{Time.now.to_i}"
    storage.size = DEFAULT_STORAGE_SIZE # GB

    client(options).create storage
  end

  def link_instances(compute_link, storage_link, options)
    slink = client(options).get_link('storagelink')
    slink.source = compute_link
    slink.target = storage_link

    client(options).create slink
  end

  def mandatory_cleanup(links, options)
    mandatory_cleanup_part links[:storagelink], true, options
    mandatory_cleanup_part links[:storage], false, options
    mandatory_cleanup_part links[:compute], false, options
  end

  def mandatory_cleanup_part(link, wait4inactive, options)
    client(options).delete link
    wait4inactive(link, options) if wait4inactive
  rescue => ex
    # ignore
  end

  def get_mixin(term, type, options)
    mxn = client(options).get_mixin(term, type, true)
    fail "Mixin #{term.inspect} of type #{type.inspect} not found at the site" unless mxn
    mxn
  end

  def wait4ready(link, options)
    state = nil

    while !READY_STATES.include?(state) do
      state = client(options).describe(link).first.state
      fail "Provisioning failure on #{link.inspect}" if ERROR_STATES.include?(state)
      sleep 5
    end
  end

  def wait4inactive(link, options)
    state = nil

    while !NONREADY_STATES.include?(state) do
      state = client(options).describe(link).first.state
      fail "De-provisioning failure on #{link.inspect}" if ERROR_STATES.include?(state)
      sleep 5
    end
  end

  def appdb_information(options)
    [appdb_appliance(options), appdb_smallest_size(options)]
  rescue => ex
    puts "COMPUTE UNKNOWN - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 3
  end

  def appdb_appliance(options)
    appliance = nil
    appliance = [appdb_provider(options)['provider:image']].flatten.compact.select do |image|
      image['mp_uri'] && (normalize_mpuri(image['mp_uri']) == normalize_mpuri(options[:mpuri]))
    end.first
    fail "Site does not have an appliance with MPURI "\
         "#{normalize_mpuri(options[:mpuri]).inspect} published in AppDB" if appliance.blank?

    appliance['va_provider_image_id'].split('#').last
  end

  def appdb_smallest_size(options)
    sizes = []
    [appdb_provider(options)['provider:template']].flatten.compact.each do |template|
      sizes << [
        template['provider_template:resource_name'].split('#').last,
        template['provider_template:main_memory_size'].to_i + (template['provider_template:physical_cpus'].to_i * CPU_SUM_WEIGHT)
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
                        fail "Could not get appliance "\
                             "details from AppDB [#{response.code}]" unless response.success?
                        response.parsed_response
                      end

    @provider = parsed_response['appdb:broker']['appdb:reply']['appdb:appdb']['virtualization:provider'].select do |prov|
      prov['provider:endpoint_url'] && (prov['provider:endpoint_url'].chomp('/') == options[:endpoint].chomp('/'))
    end.first
    fail "Could not locate site by endpoint #{options[:endpoint].inspect} in AppDB" unless @provider

    @provider
  end

  def normalize_mpuri(mpuri)
    mpuri.gsub(/\/+$/, '').gsub(/:\d+$/, '')
  end

  include Nagios::Promoo::Utils::Cache
end
