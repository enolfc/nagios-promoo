# Global deps
require 'thor'
require 'timeout'
require 'multi_xml'
require 'multi_json'
require 'httparty'

# Define modules
module Nagios; end
module Nagios::Promoo; end

# Include necessary files
require "nagios/promoo/version"
require "nagios/promoo/utils"
require "nagios/promoo/master"
