# frozen_string_literal: true

require 'rails/generators/named_base'

module RubyMCP
  module Generators
    class ToolGenerator < Rails::Generators::NamedBase
      namespace 'rubymcp:tool'

      class_option :background, type: :boolean, default: false

      source_root File.expand_path('templates', __dir__)

      def create_tool
        self.template(self.options[:background] ? 'background/tool.rb.tt' : 'tool.rb.tt', "app/tools/#{self.file_path.delete_suffix('_tool')}_tool.rb")
      end
    end
  end
end
