# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP components', type: :request do
  it 'filters discovery and rejects direct calls to hidden tools' do
    allow(GreetingTool).to receive(:visible?) { |context:| context.fetch(:current_account) == 'first' }
    ['first', 'second'].each do |account|
      headers = { 'Authorization' => "Bearer #{account}", 'Accept' => 'application/json, text/event-stream' }
      post '/mcp', params: { jsonrpc: '2.0', id: 1, method: 'tools/list' }, headers: headers, as: :json
      expect(response.parsed_body.dig('result', 'tools').pluck('name')).to eq(account == 'first' ? ['failure', 'greeting'] : ['failure'])
      post '/mcp', params: { jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'greeting', arguments: { name: 'Ada' } } }, headers: headers, as: :json
      if account == 'first'
        expect(response.parsed_body.dig('result', 'structuredContent', 'account')).to eq('first')
      else
        expect(response.parsed_body['error']).to be_present
        expect(response.body).not_to include('Hello')
      end
    end
  end

  it 'discovers and reads account-scoped resources and templates, including after reload' do
    original = ProfileResource
    Rails.application.reloader.reload!
    expect(ProfileResource).not_to equal(original)
    ['first', 'second'].each do |account|
      headers = { 'Authorization' => "Bearer #{account}", 'Accept' => 'application/json, text/event-stream' }
      post '/mcp', params: { jsonrpc: '2.0', id: 1, method: 'resources/list' }, headers: headers, as: :json
      expect(response.parsed_body.dig('result', 'resources').pluck('uri')).to eq(account == 'first' ? ['app://profile'] : [])
      post '/mcp', params: { jsonrpc: '2.0', id: 2, method: 'resources/templates/list' }, headers: headers, as: :json
      expect(response.parsed_body.dig('result', 'resourceTemplates').pluck('uriTemplate')).to eq(account == 'first' ? ['app://reports/{id}'] : [])
      ['app://profile', 'app://reports/42'].each do |uri|
        post '/mcp', params: { jsonrpc: '2.0', id: 3, method: 'resources/read', params: { uri: uri } }, headers: headers, as: :json
        if account == 'first'
          contents = response.parsed_body.dig('result', 'contents', 0)
          expect(contents['uri']).to eq(uri)
          expect(contents['mimeType']).to eq('application/json')
          expect(JSON.parse(contents['text'])['account']).to eq('first')
        else
          expect(response.body).not_to include('"account"')
          expect(response.parsed_body.dig('result', 'contents')).to eq([])
        end
      end
    end
  end

  it 'renders prompts and rejects missing, invalid and unauthorised arguments' do
    headers = { 'Authorization' => 'Bearer first', 'Accept' => 'application/json, text/event-stream' }
    post '/mcp', params: { jsonrpc: '2.0', id: 1, method: 'prompts/list' }, headers: headers, as: :json
    expect(response.parsed_body.dig('result', 'prompts').pluck('name')).to eq(['comparison'])
    post '/mcp', params: { jsonrpc: '2.0', id: 2, method: 'prompts/get', params: { name: 'comparison', arguments: { first: 'A', second: 'B' } } }, headers: headers, as: :json
    expect(response.parsed_body.dig('result', 'messages', 0, 'content', 'text')).to eq('Compare A and B for first.')
    [{}, { first: 1, second: 'B' }, { first: 'A', second: 'B', extra: 'C' }].each do |arguments|
      post '/mcp', params: { jsonrpc: '2.0', id: 3, method: 'prompts/get', params: { name: 'comparison', arguments: arguments } }, headers: headers, as: :json
      expect(response.parsed_body.dig('error', 'code')).to eq(-32_602)
    end
    headers['Authorization'] = 'Bearer second'
    post '/mcp', params: { jsonrpc: '2.0', id: 4, method: 'prompts/get', params: { name: 'comparison', arguments: { first: 'A', second: 'B' } } }, headers: headers, as: :json
    expect(response.parsed_body['error']).to be_present
    expect(response.body).not_to include('Compare A')
  end
end
