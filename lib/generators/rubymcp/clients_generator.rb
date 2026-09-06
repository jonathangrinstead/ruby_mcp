# frozen_string_literal: true

require 'rails/generators'

module RubyMCP
  module Generators
    class ClientsGenerator < Rails::Generators::Base
      namespace 'rubymcp:clients'
      source_root File.expand_path('templates', __dir__)

      def create_configuration
        self.copy_file 'rubymcp_clients.yml', 'config/rubymcp_clients.yml'
      end
    end
  end
end
