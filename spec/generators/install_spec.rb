# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'generators/rubymcp/install_generator'
require 'generators/rubymcp/tool_generator'

RSpec.describe RubyMCP::Generators::InstallGenerator do
  it 'generates an app that boots, rejects unconfigured requests and executes a namespaced tool' do
    Dir.mktmpdir('rubymcp') do |directory|
      FileUtils.mkdir_p("#{directory}/config")
      FileUtils.cp(File.expand_path('../dummy/config/application.rb', __dir__), "#{directory}/config/application.rb")
      File.write("#{directory}/config/routes.rb", "Rails.application.routes.draw do\nend\n")

      Rails::Generators.invoke('rubymcp:install', [], destination_root: directory, shell: Thor::Shell::Basic.new)
      Rails::Generators.invoke('rubymcp:tool', ['admin/echo'], destination_root: directory, shell: Thor::Shell::Basic.new)

      script = <<~RUBY
        require '#{directory}/config/application'
        request = Rack::MockRequest.new(Rails.application)
        denied = request.post('/mcp', 'HTTP_HOST' => 'localhost')
        RubyMCP.configuration.context = ->(_request) { {} }
        response = request.post('/mcp',
          'HTTP_HOST' => 'localhost',
          'CONTENT_TYPE' => 'application/json',
          'HTTP_ACCEPT' => 'application/json, text/event-stream',
          input: JSON.generate(jsonrpc: '2.0', id: 1, method: 'tools/call',
            params: { name: 'admin_echo', arguments: { message: 'It works' } }))
        puts JSON.generate(denied: denied.status, result: JSON.parse(response.body))
      RUBY

      output, errors, status = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)
      expect(status.success?).to eq(true), errors
      result = JSON.parse(output)
      expect(result['denied']).to eq(Rack::Utils.status_code(:unauthorized))
      expect(result.dig('result', 'result', 'structuredContent')).to eq('message' => 'It works')
    end
  end
end
