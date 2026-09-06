# frozen_string_literal: true

require_relative 'dummy/config/application'
require 'rspec/rails'

RSpec.configure do |config|
  config.before(:each, type: :request) do
    RubyMCP.configure do |settings|
      settings.allowed_hosts = ['www.example.com']
      settings.context = lambda do |request|
        account = { 'Bearer first' => 'first', 'Bearer second' => 'second' }[request.get_header('HTTP_AUTHORIZATION')]
        { current_account: account } if account
      end
    end
  end
end
