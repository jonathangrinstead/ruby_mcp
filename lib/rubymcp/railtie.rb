# frozen_string_literal: true

require 'rails/railtie'

module RubyMCP
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/rubymcp_clients.rake', __dir__)
    end

    config.to_prepare do
      ['tools', 'prompts', 'resources', 'resource_templates'].each do |folder|
        directory = Rails.root.join('app', folder)
        Rails.autoloaders.main.eager_load_dir(directory) if directory.directory?
      end
    end
  end
end
