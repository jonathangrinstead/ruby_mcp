# frozen_string_literal: true

require 'rails/generators/named_base'

module RubyMCP
  module Generators
    class ResourceTemplateGenerator < Rails::Generators::NamedBase
      namespace 'rubymcp:resource_template'
      source_root File.expand_path('templates', __dir__)

      def create_component
        self.copy_file 'application_resource_template.rb', 'app/resource_templates/application_resource_template.rb', skip: true
        self.template 'resource_template.rb.tt', "app/resource_templates/#{self.file_path.delete_suffix('_resource_template')}_resource_template.rb"
      end
    end
  end
end
