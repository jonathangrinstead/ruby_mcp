# frozen_string_literal: true

load File.expand_path('oauth_app.rb', __dir__)
directory = ARGV.fetch(0)
Rails::Generators.invoke('rubymcp:background', ['Account'], destination_root: directory)
['prompt', 'resource', 'resource_template'].each do |kind|
  Rails::Generators.invoke("rubymcp:#{kind}", ['example'], destination_root: directory)
end
Rails::Generators.invoke('rubymcp:tool', ['research', '--background'], destination_root: directory)
application = "#{directory}/config/application.rb"
File.write(application, File.read(application).sub("require 'active_record/railtie'", "require 'active_record/railtie'\n  require 'active_job/railtie'"))
ActiveRecord::MigrationContext.new("#{directory}/db/migrate").migrate
File.write("#{directory}/app/tools/research_tool.rb", <<~RUBY)
  class ResearchTool < ApplicationBackgroundTool
    description 'Research startups in the background'
    param :fail, type: :boolean
    def self.visible?(context:)
      context.fetch(:current_account).failed_attempts < 5
    end
    def call(fail: false)
      self.report_progress(1, total: 2, message: 'Reading profiles')
      raise 'private-database-password' if fail
      self.current_account.increment!(:failed_attempts)
      self.report_progress(2, total: 2, message: 'Compared')
      { email: self.current_account.email }
    end
  end

RUBY
