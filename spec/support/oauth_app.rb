# frozen_string_literal: true

require 'fileutils'
require 'json'

directory, model_name = ARGV
table_name = model_name.downcase + 's'
FileUtils.mkdir_p(["#{directory}/config/initializers", "#{directory}/app/models", "#{directory}/app/controllers", "#{directory}/app/views/layouts", "#{directory}/db/migrate"])
File.write("#{directory}/config/database.yml", "test:\n  adapter: sqlite3\n  database: #{directory}/db/test.sqlite3\n")
File.write("#{directory}/config/application.rb", <<~RUBY)
  ENV['RAILS_ENV'] = 'test'
  require 'rails'
  require 'active_record/railtie'
  require 'action_controller/railtie'
  require 'devise'
  require 'doorkeeper'
  require 'rubymcp'
  module OAuthTest
    class Application < Rails::Application
      config.root = #{directory.inspect}
      config.eager_load = false
      config.secret_key_base = 'test-secret-key-base'
      config.hosts = ['app.example.com']
      config.action_dispatch.show_exceptions = :none
      config.action_controller.allow_forgery_protection = true
      config.logger = Logger.new(File::NULL)
    end
  end
  Rails.application.initialize!
RUBY
File.write("#{directory}/config/initializers/devise.rb", <<~RUBY)
  require 'devise/orm/active_record'
  Devise.setup do |config|
    config.secret_key = 'devise-test-secret'
    config.mailer_sender = 'test@example.com'
    config.password_length = 12..128
    config.stretches = 1
  end
RUBY
File.write("#{directory}/app/models/#{model_name.downcase}.rb", <<~RUBY)
  class #{model_name} < ActiveRecord::Base
    devise :database_authenticatable, :validatable, :lockable
  end
RUBY
File.write("#{directory}/app/controllers/application_controller.rb", "class ApplicationController < ActionController::Base\nend\n")
File.write("#{directory}/app/views/layouts/application.html.erb", '<!doctype html><html><head><%= csrf_meta_tags %></head><body><%= yield %></body></html>')
File.write("#{directory}/config/routes.rb", "Rails.application.routes.draw do\n  devise_for :#{table_name}\nend\n")
File.write("#{directory}/db/migrate/20200101000000_create_accounts.rb", <<~RUBY)
  class CreateAccounts < ActiveRecord::Migration[7.2]
    def change
      create_table :#{table_name} do |table|
        table.string :email, null: false
        table.string :encrypted_password, null: false, default: ''
        table.integer :failed_attempts, null: false, default: 0
        table.datetime :locked_at
        table.string :unlock_token
      end
    end
  end
RUBY

require "#{directory}/config/application"
require 'rails/generators'
Rails::Generators.invoke('rubymcp:install', [], destination_root: directory)
Rails::Generators.invoke('rubymcp:devise', [model_name, '--issuer=https://app.example.com'], destination_root: directory)
require 'generators/rubymcp/devise_generator'
original = File.read("#{directory}/config/initializers/doorkeeper.rb")
begin
  RubyMCP::Generators::DeviseGenerator.new([model_name], { issuer: 'https://app.example.com' }, destination_root: directory).install
  abort 'Generator unexpectedly accepted an existing Doorkeeper configuration'
rescue Thor::Error => exception
  raise if exception.message.exclude?('already configured')
end
abort 'Generator modified the existing initializer' unless File.read("#{directory}/config/initializers/doorkeeper.rb") == original
ActiveRecord::Migration.verbose = false
ActiveRecord::MigrationContext.new("#{directory}/db/migrate").migrate
File.write("#{directory}/app/tools/identity_tool.rb", <<~RUBY)
  class IdentityTool < ApplicationTool
    description 'Return the signed-in account'
    def call
      { email: self.current_account.email }
    end
  end
RUBY
