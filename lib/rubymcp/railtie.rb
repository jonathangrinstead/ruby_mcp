# frozen_string_literal: true

require 'rails/railtie'

module RubyMCP
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/rubymcp_clients.rake', __dir__)
    end

    config.to_prepare do
      directory = Rails.root.join('app/tools')
      Rails.autoloaders.main.eager_load_dir(directory) if directory.directory?
    end
  end
end
