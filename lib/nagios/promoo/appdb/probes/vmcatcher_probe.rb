# Internal deps
require File.join(File.dirname(__FILE__), 'base_probe')

class Nagios::Promoo::Appdb::Probes::VmcatcherProbe < Nagios::Promoo::Appdb::Probes::BaseProbe
  class << self
    def description
      ['vmcatcher', 'Run a probe checking consistency between a vmcatcher image list and available appliances (via AppDB)']
    end

    def options
      [
        [:vo, { type: :string, required: true, desc: 'Virtual Organization name (used to select the appropriate VO-wide image list)' }],
        [:token, { type: :string, required: true, desc: 'AppDB authentication token (used to access the VO-wide image list)' }],
        [:missing_critical, { type: :numeric, default: 2, desc: 'Number of missing appliances to be considered CRITICAL' }],
        [:outdated_critical, { type: :numeric, default: 5, desc: 'Number of outdated appliances to be considered CRITICAL' }],
      ]
    end

    def declaration
      "vmcatcher"
    end

    def runnable?; true; end
  end

  IMAGE_LIST_TEMPLATE = "https://$$TOKEN$$:x-oauth-basic@vmcaster.appdb.egi.eu/store/vo/$$VO$$/image.list"
  IMAGE_LIST_BOUNDARY_REGEXP = /boundary="(?<prefix>-+)(?<id>[[:alnum:]]+)"/

  def run(args = [])
    @_results = { found: [], outdated: [], missing: [], expected: [] }

    Timeout::timeout(options[:timeout]) { check_vmc_sync }

    if @_results[:missing].count >= options[:missing_critical]
      puts "VMCATCHER CRITICAL - #{@_results[:missing].count} appliance(s) in #{options[:vo].inspect} missing"
      exit 2
    end

    if @_results[:outdated].count >= options[:outdated_critical]
      puts "VMCATCHER CRITICAL - #{@_results[:outdated].count} appliance(s) in #{options[:vo].inspect} outdated"
      exit 2
    end

    if @_results[:outdated].count > 0
      puts "VMCATCHER WARNING - #{@_results[:outdated].count} appliances in #{options[:vo].inspect} outdated"
      exit 1
    end

    puts "VMCATCHER OK - All appliances registered in #{options[:vo].inspect} are available [#{@_results[:expected].count}]"
  rescue => ex
    puts "VMCATCHER UNKNOWN - #{ex.message}"
    puts ex.backtrace if options[:debug]
    exit 3
  end

  private

  def check_vmc_sync
    vo_list.each do |hv_image|
      mpuri_versionless = versionless_mpuri(hv_image['ad:mpuri'])
      @_results[:expected] << mpuri_versionless

      matching = provider_appliances.select { |appl| appl['mp_uri'] == mpuri_versionless }.first

      unless matching
        @_results[:missing] << mpuri_versionless
        next
      end

      @_results[:outdated] << mpuri_versionless if hv_image['hv:version'] != matching['vmiversion']
      @_results[:found] << mpuri_versionless
    end
  end

  def provider_appliances
    return @_appliances if @_appliances

    @_appliances = [appdb_provider['provider:image']].flatten.compact
    @_appliances.keep_if { |appliance| appliance['voname'] == options[:vo] }
    @_appliances.reject { |appliance| appliance['mp_uri'].blank? }

    @_appliances.each do |appliance|
      appliance['mp_uri'] = versionless_mpuri(appliance['mp_uri'])
    end

    @_appliances
  end

  def vo_list
    return @_hv_images if @_hv_images

    list_url = IMAGE_LIST_TEMPLATE.gsub('$$TOKEN$$', options[:token]).gsub('$$VO$$', options[:vo])
    response = HTTParty.get list_url
    fail "Could not get a VO-wide image list" \
         "from #{list_url.inspect} [#{response.code}]" unless response.success?

    list = JSON.parse OpenSSL::PKCS7.read_smime(response.parsed_response).data
    fail "AppDB image list #{list_url.inspect} does " \
         "not contain images" unless list && list['hv:imagelist'] && list['hv:imagelist']['hv:images']

    @_hv_images = list['hv:imagelist']['hv:images'].collect { |im| im['hv:image'] }.reject { |im| im.blank? || im['ad:mpuri'].blank? }
  end

  def normalize_mpuri(mpuri)
    mpuri.gsub(/\/+$/, '')
  end

  def versionless_mpuri(mpuri)
    normalize_mpuri(mpuri).gsub(/:\d+$/, '')
  end
end
