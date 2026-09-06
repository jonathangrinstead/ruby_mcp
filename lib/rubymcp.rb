# frozen_string_literal: true

require 'mcp'
require 'active_support'
require 'active_support/core_ext/class/subclasses'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/inflections'
require_relative 'rubymcp/version'
require_relative 'rubymcp/authentication_error'
require_relative 'rubymcp/component'
require_relative 'rubymcp/tool'
require_relative 'rubymcp/prompt'
require_relative 'rubymcp/resource_content'
require_relative 'rubymcp/resource'
require_relative 'rubymcp/resource_template'
require_relative 'rubymcp/configuration'
require_relative 'rubymcp/endpoint'
require_relative 'rubymcp/railtie'

module RubyMCP
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield self.configuration
  end
end
