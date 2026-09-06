# frozen_string_literal: true

require 'tmpdir'
require 'open3'

RSpec.describe 'Devise OAuth generator' do
  ['Account', 'User'].each do |model_name|
    it "connects a client through Devise #{model_name} sign-in, consent, PKCE and scoped tokens" do
      Dir.mktmpdir('rubymcp-oauth') do |directory|
        library = File.expand_path('../../lib', __dir__)
        setup = File.expand_path('../support/oauth_app.rb', __dir__)
        flow = File.expand_path('../support/oauth_flow.rb', __dir__)
        output, errors, status = Open3.capture3(RbConfig.ruby, '-I', library, setup, directory, model_name)
        expect(status.success?).to eq(true), "#{output}\n#{errors}"
        output, errors, status = Open3.capture3(RbConfig.ruby, '-I', library, flow, directory, model_name)
        expect(status.success?).to eq(true), "#{output}\n#{errors}"
        result = JSON.parse(output.lines.last)
        expect(result.dig('resource_metadata', 'resource')).to eq('https://app.example.com/mcp')
        expect(result.dig('server_metadata', 'code_challenge_methods_supported')).to eq(['S256'])
        expect(result['unauthenticated']).to eq(Rack::Utils.status_code(:unauthorized))
        expect(result['challenge']).to include('resource_metadata="https://app.example.com/.well-known/oauth-protected-resource/mcp"')
        expect(result['sign_in_redirect']).to eq("/#{model_name.downcase}s/sign_in")
        expect(result['consent_status']).to eq(Rack::Utils.status_code(:ok))
        expect(result['consent_visible']).to eq(true)
        expect(result['returned_state']).to eq('test-state')
        expect(result['token_status']).to eq(Rack::Utils.status_code(:ok))
        expect(result['secret_hashed']).to eq(true)
        expect(result['identity']).to eq('email' => 'first@example.com')
        expect(result['second']).to eq('email' => 'second@example.com')
        expect(result['refresh_status']).to eq(Rack::Utils.status_code(:ok))
        expect(result['refreshed_identity']).to eq('email' => 'first@example.com')
        expect(result['denied_consent']).to eq('access_denied')
        expect(result['csrf_failure']).to eq(Rack::Utils.status_code(:unprocessable_entity))
        ['bad_verifier', 'replayed_code', 'bad_redirect', 'missing_pkce', 'bad_resource', 'old_refresh'].each do |scenario|
          expect(result[scenario]).to eq(Rack::Utils.status_code(:bad_request)), scenario
        end
        ['cookie_only', 'revoked', 'expired', 'wrong_audience', 'unbound', 'locked_account', 'deleted_account'].each do |scenario|
          expect(result[scenario]).to eq(Rack::Utils.status_code(:unauthorized)), scenario
        end
        expect(result['wrong_scope']).to eq(Rack::Utils.status_code(:forbidden))
        expect(result['additional_callback']).to eq(Rack::Utils.status_code(:ok))
        expect(result['removed_callback']).to eq(Rack::Utils.status_code(:bad_request))
        expect(result['preserved_client']).to eq(true)
        expect(result['admin_routes']).to eq(Rack::Utils.status_code(:not_found))
      end
    end
  end
end
