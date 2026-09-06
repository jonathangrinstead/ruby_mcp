# frozen_string_literal: true

require 'json'
require 'uri'
require 'digest'
require 'base64'
require 'rack/test'
require 'nokogiri'

directory, model_name = ARGV
require "#{directory}/config/application"
model = model_name.constantize
account = model.create!(email: 'first@example.com', password: 'a-long-test-password')
second = model.create!(email: 'second@example.com', password: 'a-long-test-password')
Rails.application.load_tasks
ENV['NAME'] = 'Test Claude'
ENV['REDIRECT_URI'] = 'https://client.example/callback'
Rake::Task['rubymcp:register_client'].invoke
client = Doorkeeper::Application.find_by!(name: 'Test Claude')
require 'yaml'
configuration_path = Rails.root.join('config/rubymcp_clients.yml')
raise 'Missing generated clients file' unless YAML.safe_load_file(configuration_path) == {}
clients = { 'claude' => { 'name' => 'Test Claude', 'client_id' => client.uid, 'redirect_uris' => ['https://client.example/callback', 'https://client.example/second'] } }
File.write(configuration_path, clients.to_yaml)
Rake::Task['rubymcp:clients:sync'].invoke
client.reload
session = Rack::Test::Session.new(Rails.application)
session.header('HOST', 'app.example.com')
session.header('X-Forwarded-Proto', 'https')
result = {}
session.get('/.well-known/oauth-protected-resource/mcp')
result[:resource_metadata] = JSON.parse(session.last_response.body)
session.get('/.well-known/oauth-authorization-server')
result[:server_metadata] = JSON.parse(session.last_response.body)
session.post('/mcp', '{}', 'CONTENT_TYPE' => 'application/json')
result[:unauthenticated] = session.last_response.status
result[:challenge] = session.last_response['www-authenticate']

verifier = 'a' * 64
parameters = {
  client_id: client.uid, redirect_uri: 'https://client.example/second', response_type: 'code', scope: 'mcp',
  state: 'test-state', resource: 'https://app.example.com/mcp',
  code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false), code_challenge_method: 'S256'
}
session.get('/oauth/authorize', parameters)
result[:sign_in_redirect] = URI.parse(session.last_response.location).path
session.follow_redirect!
csrf = Nokogiri::HTML(session.last_response.body).at_css('input[name="authenticity_token"]')['value']
session.post("/#{model_name.downcase}s/sign_in", {
  authenticity_token: csrf, model_name.downcase => { email: account.email, password: 'a-long-test-password' }
})
session.get('/oauth/authorize', parameters)
result[:consent_status] = session.last_response.status
result[:consent_visible] = session.last_response.body.include?('Use tools with your account')
csrf = Nokogiri::HTML(session.last_response.body).at_css('input[name="authenticity_token"]')['value']
session.post('/oauth/authorize', parameters.merge(authenticity_token: csrf))
query = URI.decode_www_form(URI.parse(session.last_response.location).query).to_h
result[:returned_state] = query['state']
token_params = { grant_type: 'authorization_code', code: query.fetch('code'), client_id: client.uid, redirect_uri: 'https://client.example/second', resource: parameters[:resource] }
session.post('/oauth/token', token_params.merge(code_verifier: 'wrong' * 12))
result[:bad_verifier] = session.last_response.status
session.post('/oauth/token', token_params.merge(code_verifier: verifier))
tokens = JSON.parse(session.last_response.body)
result[:token_status] = session.last_response.status
access_token = tokens.fetch('access_token')
result[:secret_hashed] = Doorkeeper::AccessToken.by_token(access_token).token != access_token

payload = JSON.generate(jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'identity', arguments: {} })
headers = { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json, text/event-stream' }
session.post('/mcp', payload, headers)
result[:cookie_only] = session.last_response.status
session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{access_token}"))
result[:identity] = JSON.parse(session.last_response.body).dig('result', 'structuredContent')

session.post('/oauth/token', grant_type: 'refresh_token', refresh_token: tokens.fetch('refresh_token'), client_id: client.uid, resource: parameters[:resource])
refreshed = JSON.parse(session.last_response.body)
result[:refresh_status] = session.last_response.status
session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{refreshed.fetch('access_token')}"))
result[:refreshed_identity] = JSON.parse(session.last_response.body).dig('result', 'structuredContent')
session.post('/oauth/token', grant_type: 'refresh_token', refresh_token: tokens.fetch('refresh_token'), client_id: client.uid, resource: parameters[:resource])
result[:old_refresh] = session.last_response.status
session.post('/oauth/revoke', token: refreshed.fetch('access_token'), client_id: client.uid)
session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{refreshed.fetch('access_token')}"))
result[:revoked] = session.last_response.status
session.post('/oauth/token', token_params.merge(code_verifier: verifier))
result[:replayed_code] = session.last_response.status

{
  second: { resource_owner_id: second.id },
  expired: { expires_in: -1 },
  wrong_audience: { resource: 'https://other.example/mcp' },
  unbound: { resource: nil },
  wrong_scope: { scopes: '' }
}.each do |scenario, attributes|
  token = Doorkeeper::AccessToken.create!({ resource_owner_id: account.id, application_id: client.id, scopes: 'mcp', resource: parameters[:resource], expires_in: 3600 }.merge(attributes))
  session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{token.plaintext_token}"))
  result[scenario] = scenario == :second ? JSON.parse(session.last_response.body).dig('result', 'structuredContent') : session.last_response.status
  if scenario == :second
    second.lock_access!(send_instructions: false)
    session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{token.plaintext_token}"))
    result[:locked_account] = session.last_response.status
    second.destroy!
    session.post('/mcp', payload, headers.merge('HTTP_AUTHORIZATION' => "Bearer #{token.plaintext_token}"))
    result[:deleted_account] = session.last_response.status
  end
end

session.get('/oauth/authorize', parameters.merge(redirect_uri: 'https://evil.example/callback'))
result[:bad_redirect] = session.last_response.status
session.get('/oauth/authorize', parameters.except(:code_challenge, :code_challenge_method))
result[:missing_pkce] = session.last_response.status
session.get('/oauth/authorize', parameters.merge(resource: 'https://other.example/mcp'))
result[:bad_resource] = session.last_response.status
session.get('/oauth/authorize', parameters)
csrf = Nokogiri::HTML(session.last_response.body).at_css('input[name="authenticity_token"]')['value']
session.delete('/oauth/authorize', parameters.merge(authenticity_token: csrf))
result[:denied_consent] = URI.decode_www_form(URI.parse(session.last_response.location).query).to_h['error']
begin
  session.post('/oauth/authorize', parameters)
  result[:csrf_failure] = session.last_response.status
rescue ActionController::InvalidAuthenticityToken
  result[:csrf_failure] = Rack::Utils.status_code(:unprocessable_entity)
end
begin
  session.get('/oauth/applications')
  result[:admin_routes] = session.last_response.status
rescue ActionController::RoutingError
  result[:admin_routes] = Rack::Utils.status_code(:not_found)
end
session.get('/oauth/authorize', parameters.merge(redirect_uri: 'https://client.example/callback'))
result[:additional_callback] = session.last_response.status
clients['claude']['redirect_uris'] = ['https://client.example/second']
File.write(configuration_path, clients.to_yaml)
Rake::Task['rubymcp:clients:sync'].reenable
Rake::Task['rubymcp:clients:sync'].invoke
session.get('/oauth/authorize', parameters.merge(redirect_uri: 'https://client.example/callback'))
result[:removed_callback] = session.last_response.status
result[:preserved_client] = client.reload.uid == clients['claude']['client_id']
puts JSON.generate(result)
