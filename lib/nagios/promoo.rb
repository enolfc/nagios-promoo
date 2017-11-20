# Global deps
require 'active_support/all'
require 'thor'
require 'timeout'
require 'ox'
require 'multi_xml'
require 'httparty'
require 'time'

# Force multi_xml to use ox
MultiXml.parser = :ox

# Gem namespace module.
#
# @author Boris Parak <parak@cesnet.cz>
module Nagios
  # Namespace for `promoo` classes and modules.
  #
  # @author Boris Parak <parak@cesnet.cz>
  module Promoo; end
end

# Include necessary files
require 'nagios/promoo/version'
require 'nagios/promoo/utils'
require 'nagios/promoo/master'
