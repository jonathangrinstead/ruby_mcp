# frozen_string_literal: true

require 'tmpdir'
require 'open3'

RSpec.describe 'OAuth client configuration' do
  it 'preserves registrations and applies only valid configuration atomically' do
    Dir.mktmpdir('rubymcp-clients') do |directory|
      library = File.expand_path('../../lib', __dir__)
      setup = File.expand_path('../support/oauth_app.rb', __dir__)
      flow = File.expand_path('../support/client_registry_flow.rb', __dir__)
      output, errors, status = Open3.capture3(RbConfig.ruby, '-I', library, setup, directory, 'Account')
      expect(status.success?).to eq(true), "#{output}\n#{errors}"
      output, errors, status = Open3.capture3(RbConfig.ruby, '-I', library, flow, directory)
      expect(status.success?).to eq(true), "#{output}\n#{errors}"
    end
  end
end
