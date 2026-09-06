# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP endpoint', type: :request do
  before do
    @headers = { 'Authorization' => 'Bearer first', 'Accept' => 'application/json, text/event-stream' }
  end

  it 'initialises and discovers concrete tools without manually registering them' do
    post '/mcp', params: {
      jsonrpc: '2.0', id: 1, method: 'initialize',
      params: { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'spec', version: '1' } }
    }, headers: @headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('result', 'serverInfo', 'name')).to eq('rails_app')
    expect(response.headers['Mcp-Session-Id']).to be_nil

    post '/mcp', params: { jsonrpc: '2.0', id: 2, method: 'tools/list' }, headers: @headers, as: :json
    expect(response).to have_http_status(:ok)
    tools = response.parsed_body.dig('result', 'tools')
    expect(tools.pluck('name')).to eq(['failure', 'greeting'])
    expect(tools.last.dig('inputSchema', 'required')).to eq(['name'])
  end

  it 'isolates account context and tool instance state between requests' do
    ['first', 'second'].each do |account|
      post '/mcp', params: {
        jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'greeting', arguments: { name: 'Ada' } }
      }, headers: @headers.merge('Authorization' => "Bearer #{account}"), as: :json

      expect(response).to have_http_status(:ok)
      result = response.parsed_body.fetch('result')
      expect(result['structuredContent']).to eq('message' => 'Hello, Ada!', 'account' => account, 'calls' => 1)
      expect(JSON.parse(result.fetch('content').first.fetch('text'))).to eq(result['structuredContent'])
    end
  end

  it 'validates missing, mistyped and unknown arguments before invoking Ruby' do
    [{}, { name: 42 }, { name: 'Ada', unexpected: true }].each do |arguments|
      post '/mcp', params: {
        jsonrpc: '2.0', id: 4, method: 'tools/call', params: { name: 'greeting', arguments: arguments }
      }, headers: @headers, as: :json
      expect(response.parsed_body.dig('result', 'isError')).to eq(true)
      expect(response.parsed_body.dig('result', 'content', 0, 'text')).to match(/arguments/i)
    end
  end

  it 'rejects unauthenticated requests before listing or invoking tools' do
    post '/mcp', params: { jsonrpc: '2.0', id: 5, method: 'tools/list' }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq('error' => 'Unauthorised')
  end

  it 'returns expected tool errors and hides unexpected exception details' do
    post '/mcp', params: {
      jsonrpc: '2.0', id: 6, method: 'tools/call', params: { name: 'failure', arguments: { expected: true } }
    }, headers: @headers, as: :json
    expect(response.parsed_body.dig('result', 'isError')).to eq(true)
    expect(response.parsed_body.dig('result', 'content', 0, 'text')).to eq('Invoice is already paid')

    post '/mcp', params: {
      jsonrpc: '2.0', id: 7, method: 'tools/call', params: { name: 'failure', arguments: { expected: false } }
    }, headers: @headers, as: :json
    expect(response.parsed_body.dig('error', 'code')).to eq(-32_603)
    expect(response.body).not_to include('private-database-password')
  end

  it 'rejects cross-origin requests using the SDK transport' do
    post '/mcp', params: { jsonrpc: '2.0', id: 8, method: 'tools/list' },
      headers: @headers.merge('Origin' => 'https://untrusted.example'), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include('greeting')
  end

  it 'uses fresh classes after a Rails reload' do
    original = GreetingTool
    Rails.application.reloader.reload!
    expect(GreetingTool).not_to equal(original)

    post '/mcp', params: { jsonrpc: '2.0', id: 9, method: 'tools/list' }, headers: @headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('result', 'tools').pluck('name')).to eq(['failure', 'greeting'])
  end

  it 'accepts notifications and delegates malformed JSON to the SDK' do
    post '/mcp', params: { jsonrpc: '2.0', method: 'notifications/initialized' }, headers: @headers, as: :json
    expect(response).to have_http_status(:accepted)
    expect(response.body).to eq('')

    post '/mcp', params: '{', headers: @headers.merge('Content-Type' => 'application/json')
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig('error', 'code')).to eq(-32_700)
  end
end
