# frozen_string_literal: true

require 'rails/generators/named_base'
require 'rails/generators/active_record'

module RubyMCP
  module Generators
    class BackgroundGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      namespace 'rubymcp:background'
      source_root File.expand_path('templates', __dir__)
      argument :name, type: :string, default: 'Account'

      def install
        if Dir.glob(File.join(self.destination_root, 'db/migrate/*_create_rubymcp_tasks.rb')).any?
          raise Thor::Error, 'RubyMCP background tasks are already installed'
        end
        self.migration_template 'background/migration.rb.tt', 'db/migrate/create_rubymcp_tasks.rb'
        self.template 'background/initializer.rb.tt', 'config/initializers/rubymcp_background.rb'
        self.copy_file 'background/application_background_tool.rb', 'app/tools/application_background_tool.rb'
        self.copy_file 'background/tasks.rake', 'lib/tasks/rubymcp_background.rake'
      end
    end
  end
end
