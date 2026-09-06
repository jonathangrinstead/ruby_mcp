# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'rubymcp'

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.enable_reloading = true
    config.action_dispatch.show_exceptions = :none
    config.secret_key_base = 'test-secret-key-base'
    config.hosts = ['www.example.com', 'localhost']
    config.logger = Logger.new(File::NULL)
  end
end

Rails.application.initialize!
