# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tool visibility', type: :request do
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

end
