# frozen_string_literal: true

require 'rails/generators'

module RubyMCP
  module Generators
    class InstallGenerator < Rails::Generators::Base
      namespace 'rubymcp:install'

      source_root File.expand_path('templates', __dir__)

      def install
        self.copy_file 'application_tool.rb', 'app/tools/application_tool.rb'
        self.copy_file 'rubymcp.rb', 'config/initializers/rubymcp.rb'
        self.route "mount RubyMCP::Endpoint.new => '/mcp'"
      end
    end
  end
end
