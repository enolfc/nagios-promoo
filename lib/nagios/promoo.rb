# Global deps
require 'thor'
require 'timeout'

# Define modules
module Nagios; end
module Nagios::Promoo; end

# Include necessary files
require "nagios/promoo/version"
require "nagios/promoo/master"
