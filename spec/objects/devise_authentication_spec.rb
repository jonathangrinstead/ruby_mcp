# frozen_string_literal: true

require 'rubymcp/devise_authentication'

RSpec.describe RubyMCP::DeviseAuthentication do
  it 'uses a configured HTTPS origin and allows HTTP only for local development' do
    authentication = RubyMCP::DeviseAuthentication.new(model: 'Account', issuer: 'https://app.example.com/')
    expect(authentication.resource).to eq('https://app.example.com/mcp')
    expect(authentication.issuer).to eq('https://app.example.com')
    local = RubyMCP::DeviseAuthentication.new(model: 'User', issuer: 'http://localhost:3000')
    expect(local.resource).to eq('http://localhost:3000/mcp')

    ['http://app.example.com', 'https://app.example.com/path', 'https://user:password@app.example.com', 'https://app.example.com?query=1'].each do |issuer|
      expect { RubyMCP::DeviseAuthentication.new(model: 'Account', issuer: issuer) }.to raise_error(ArgumentError)
    end
  end
end
