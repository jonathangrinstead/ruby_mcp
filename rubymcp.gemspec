# frozen_string_literal: true

require_relative 'lib/rubymcp/version'

Gem::Specification.new do |spec|
  spec.name = 'rubymcp'
  spec.version = RubyMCP::VERSION
  spec.authors = ['Jonathan Grinstead']
  spec.summary = 'Rails-native tools built on the official MCP SDK'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  spec.add_dependency 'mcp', '~> 1.4.0'
  spec.add_dependency 'railties', '>= 7.2', '< 9'
end
