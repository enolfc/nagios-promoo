# Internal deps
require File.join(File.dirname(__FILE__), 'version')

# Define modules
module Nagios::Promoo::Appdb; end
module Nagios::Promoo::Appdb::Probes; end
Dir.glob(File.join(File.dirname(__FILE__), 'probes', '*.rb')) { |probe| require probe.chomp('.rb') }

class Nagios::Promoo::Appdb::Master < ::Thor
  class << self
    # Hack to override the help message produced by Thor.
    # https://github.com/wycats/thor/issues/261#issuecomment-16880836
    def banner(command, namespace = nil, subcommand = nil)
      "#{basename} appdb #{command.usage}"
    end

    def available_probes
      Nagios::Promoo::Appdb::Probes.constants.collect { |probe| Nagios::Promoo::Appdb::Probes.const_get(probe) }.reject { |probe| !probe.runnable? }
    end
  end

  class_option :endpoint, type: :string, desc: 'Site\'s OCCI endpoint, as specified in GOCDB', default: 'http://localhost:3000/'

  available_probes.each do |probe|
    desc *probe.description
    probe.options.each do |opt|
      option opt.first, opt.last
    end
    class_eval %Q^
def #{probe.declaration}(*args)
  #{probe}.new(options).run(args)
end
^
  end

  desc 'version', 'Print version of the AppDB probe set'
  def version
    puts Nagios::Promoo::Appdb::VERSION
  end
end
