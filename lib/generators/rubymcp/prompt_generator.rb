# frozen_string_literal: true

require 'rails/generators/named_base'

module RubyMCP
  module Generators
    class PromptGenerator < Rails::Generators::NamedBase
      namespace 'rubymcp:prompt'
      source_root File.expand_path('templates', __dir__)

      def create_component
        self.copy_file 'application_prompt.rb', 'app/prompts/application_prompt.rb', skip: true
        self.template 'prompt.rb.tt', "app/prompts/#{self.file_path.delete_suffix('_prompt')}_prompt.rb"
      end
    end
  end
end
