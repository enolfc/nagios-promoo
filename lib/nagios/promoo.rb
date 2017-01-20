# Global deps
require 'thor'
require 'timeout'
require 'ox'
require 'multi_xml'
require 'httparty'

# Force multi_xml to use ox
MultiXml.parser = :ox

# Define modules
module Nagios; end
module Nagios::Promoo; end

# Include necessary files
require "nagios/promoo/version"
require "nagios/promoo/utils"
require "nagios/promoo/master"
