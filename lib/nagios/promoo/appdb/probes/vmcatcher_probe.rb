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

  def run(options, args = [])
    results = begin
                Timeout::timeout(options[:timeout]) { check_vmc_sync(options) }
              rescue => ex
                puts "VMCATCHER CRITICAL - #{ex.message}"
                puts ex.backtrace if options[:debug]
                exit 2
              end

    if results[:missing].count >= options[:missing_critical]
      puts "VMCATCHER CRITICAL - #{results[:missing].count} appliance(s) in #{options[:vo].inspect} missing"
      exit 2
    end

    ## TODO: checking for outdated appliances is not working yet
    ##
    # if results[:outdated].count >= options[:outdated_critical]
    #   puts "VMCATCHER CRITICAL - #{results[:outdated].count} appliance(s) in #{options[:vo].inspect} outdated"
    #   exit 2
    # end
    #
    # if results[:outdated].count > 0
    #   puts "VMCATCHER WARNING - #{results[:outdated].count} appliances in #{options[:vo].inspect} outdated"
    #   exit 1
    # end

    puts "VMCATCHER OK - All appliances registered in #{options[:vo].inspect} are available [#{results[:expected].count}]"
  end

  private

  def check_vmc_sync(options)
    results = { found: [], outdated: [], missing: [], expected: [] }

    vo_list(options).each do |mpuri|
      mpuri_versionless = versionless_mpuri(mpuri)
      mpuri_normalized = normalize_mpuri(mpuri)
      results[:expected] << mpuri_versionless

      if normalized_appliances(options).include?(mpuri_normalized)
        results[:found] << mpuri_normalized
      elsif versionless_appliances(options).include?(mpuri_versionless)
        results[:found] << mpuri_versionless
        results[:outdated] << mpuri_versionless
      else
        results[:missing] << mpuri_versionless
      end
    end

    results
  end

  def provider_appliances(options)
    images = [appdb_provider(options)['image']].flatten.compact
    images.collect { |image| image['mp_uri'] }.reject { |mpuri| mpuri.blank? }
  end

  def normalized_appliances(options)
    provider_appliances(options).collect { |mpuri| normalize_mpuri(mpuri) }
  end

  def versionless_appliances(options)
    provider_appliances(options).collect { |mpuri| versionless_mpuri(mpuri) }
  end

  def vo_list(options)
    return @mpuris if @mpuris

    list = nil
    begin
      list_url = IMAGE_LIST_TEMPLATE.gsub('$$TOKEN$$', options[:token]).gsub('$$VO$$', options[:vo])
      response = HTTParty.get(list_url)
      fail "Could not get a VO-wide image list" \
           "from #{list_url.inspect} [#{response.code}]" unless response.success?

      list = JSON.parse(OpenSSL::PKCS7.read_smime(response.parsed_response).data) # TODO: validate the signature?
      fail "AppDB image list #{list_url.inspect} does " \
           "not contain images" unless list && list['hv:imagelist'] && list['hv:imagelist']['hv:images']
    rescue => ex
      puts "VMCATCHER UNKNOWN - #{ex.message}"
      puts ex.backtrace if options[:debug]
      exit 3
    end

    @mpuris = list['hv:imagelist']['hv:images'].collect { |im| im['hv:image']['ad:mpuri'] }.reject { |uri| uri.blank? }
  end

  def normalize_mpuri(mpuri)
    mpuri.gsub(/\/+$/, '')
  end

  def versionless_mpuri(mpuri)
    normalize_mpuri(mpuri).gsub(/:\d+$/, '')
  end
end
