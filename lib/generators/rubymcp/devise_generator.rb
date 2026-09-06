# frozen_string_literal: true

require 'rails/generators/named_base'
require 'rubymcp/devise_authentication'

module RubyMCP
  module Generators
    class DeviseGenerator < Rails::Generators::NamedBase
      namespace 'rubymcp:devise'
      source_root File.expand_path('templates/devise', __dir__)
      class_option :issuer, type: :string, required: true, desc: 'Public HTTPS origin, e.g. https://app.example.com'

      def install
        self.validate_setup!
        self.invoke 'doorkeeper:migration'
        self.invoke 'doorkeeper:pkce'
        self.invoke 'doorkeeper:resource_indicators'
        self.template 'doorkeeper.rb.tt', 'config/initializers/doorkeeper.rb'
        self.template 'rubymcp_devise.rb.tt', 'config/initializers/rubymcp_devise.rb'
        self.copy_file 'connector_authorizations_controller.rb', 'app/controllers/connector_authorizations_controller.rb'
        self.copy_file 'rubymcp.en.yml', 'config/locales/rubymcp.en.yml'
        self.copy_file 'rubymcp.rake', 'lib/tasks/rubymcp.rake'
        self.invoke 'rubymcp:clients'
        self.route "use_doorkeeper do\n  skip_controllers :applications\n  controllers authorizations: 'connector_authorizations'\nend"
        self.route "get '/.well-known/oauth-protected-resource/mcp', to: ->(env) { RubyMCP.configuration.context.metadata(env) }"
      end

      private

      def validate_setup!
        require 'doorkeeper'
        Rails.application.routes_reloader.execute_unless_loaded
        unless Doorkeeper::VERSION::STRING == '6.0.0.beta2'
          raise Thor::Error, 'This integration requires doorkeeper 6.0.0.beta2'
        end

        model = self.class_name.safe_constantize
        unless model.respond_to?(:devise_modules) && Devise.mappings.values.any? { |mapping| mapping.to == model }
          raise Thor::Error, 'Pass an existing, routed Devise model, e.g. Account or User'
        end

        if Rails.application.config.api_only
          raise Thor::Error, 'This generator requires a Rails app with browser sessions and a Devise sign-in page'
        end

        if model.table_exists? && model.columns_hash.fetch(model.primary_key).type != :integer
          raise Thor::Error, 'Non-integer account IDs require a customised Doorkeeper migration; use the manual integration instructions'
        end

        if File.exist?(File.join(self.destination_root, 'config/initializers/doorkeeper.rb')) ||
            Dir[File.join(self.destination_root, 'db/migrate/*doorkeeper*')].any?
          raise Thor::Error, 'Doorkeeper is already configured; see the manual integration instructions'
        end

        unless File.exist?(File.join(self.destination_root, 'config/initializers/rubymcp.rb'))
          raise Thor::Error, 'Run rubymcp:install first'
        end

        RubyMCP::DeviseAuthentication.new(model: self.class_name, issuer: self.options[:issuer])
      rescue LoadError
        raise Thor::Error, "Add gem 'doorkeeper', '= 6.0.0.beta2' and run bundle install first"
      end
    end
  end
end
