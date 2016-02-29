# Deps
## None

# Include available probe modules
Dir.glob(File.join(File.dirname(__FILE__), '*', 'master.rb')) { |mod| require mod.chomp('.rb') }

class Nagios::Promoo::Master < ::Thor
  class_option :debug, type: :boolean, desc: 'Turn on debugging mode', default: false
  class_option :ca_path, type: :string, desc: 'Path to a directory with CA certificates', default: '/etc/grid-security/certificates'
  class_option :ca_file, type: :string, desc: 'Path to a file with CA certificates'
  class_option :insecure, type: :boolean, desc: 'Turn on insecure mode (without SSL client validation)', default: false
  class_option :timeout, type: :numeric, desc: 'Timeout for all internal connections and other processes (in seconds)', default: 720

  desc 'opennebula PROBE', 'Run the given probe for OpenNebula'
  subcommand 'opennebula', Nagios::Promoo::Opennebula::Master

  desc 'occi PROBE', 'Run the given probe for OCCI'
  subcommand 'occi', Nagios::Promoo::Occi::Master

  desc 'version', 'Print PROMOO version'
  def version
    puts Nagios::Promoo::VERSION
  end

  class << self
    # Force thor to exit with a non-zero return code on failure
    def exit_on_failure?; true; end
  end
end
