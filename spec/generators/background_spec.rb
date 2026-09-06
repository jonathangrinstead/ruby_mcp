# frozen_string_literal: true

require 'tmpdir'
require 'open3'

RSpec.describe 'Background tool installation' do
  it 'queues durable work, reports results and enforces ownership, cancellation and current permissions' do
    Dir.mktmpdir('rubymcp-background') do |directory|
      library = File.expand_path('../../lib', __dir__)
      ['background_app', 'background_flow'].each do |script|
        path = File.expand_path("../support/#{script}.rb", __dir__)
        output, errors, status = Open3.capture3(RbConfig.ruby, '-I', library, path, directory, 'Account')
        expect(status.success?).to eq(true), "#{output}\n#{errors}"
      end
    end
  end
end
