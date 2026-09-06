# frozen_string_literal: true

require 'rails/generators/named_base'

module RubyMCP
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      namespace 'rubymcp:resource'
      source_root File.expand_path('templates', __dir__)

      def create_component
        self.copy_file 'application_resource.rb', 'app/resources/application_resource.rb', skip: true
        self.template 'resource.rb.tt', "app/resources/#{self.file_path.delete_suffix('_resource')}_resource.rb"
      end
    end
  end
end
