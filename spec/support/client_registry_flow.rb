# frozen_string_literal: true

require "#{ARGV.fetch(0)}/config/application"
require 'rubymcp/client_registry'
require 'rspec/expectations'
include RSpec::Matchers

path = Rails.root.join('config/rubymcp_clients.yml')
registry = RubyMCP::ClientRegistry.new(path)
clients = { 'example' => { 'name' => 'Example', 'redirect_uris' => ['https://client.example/callback'] } }
File.write(path, clients.to_yaml)
expect(registry.sync!).to eq('example' => 'rubymcp_example')
application = Doorkeeper::Application.find_by!(uid: 'rubymcp_example')
expect(application.confidential?).to eq(false)
expect(application.scopes.to_s).to eq('mcp')
clients['example']['name'] = 'Renamed'
clients['example']['redirect_uris'] << 'https://client.example/second'
File.write(path, clients.to_yaml)
expect(registry.sync!).to eq('example' => application.uid)
expect(application.reload.name).to eq('Renamed')
expect(application.redirect_uri).to eq("https://client.example/callback\nhttps://client.example/second")
expect { registry.sync! }.not_to change { application.reload.updated_at }
expect(Doorkeeper::Application.count).to eq(1)

clients['example']['name'] = 'Must roll back'
clients['missing'] = { 'name' => 'Missing', 'client_id' => 'unknown', 'redirect_uris' => ['https://other.example/callback'] }
File.write(path, clients.to_yaml)
expect { registry.sync! }.to raise_error(ArgumentError, /does not match/)
expect(application.reload.name).to eq('Renamed')
clients.delete('missing')
['http://client.example/callback', 'https://client.example/*', 'https://user:password@client.example/callback', 'https://client.example/#fragment', 42].each do |url|
  clients['example']['redirect_uris'] = ['https://client.example/callback', url]
  File.write(path, clients.to_yaml)
  expect { registry.sync! }.to raise_error(ArgumentError, /callbacks/)
  expect(application.reload.name).to eq('Renamed')
end
clients['example']['redirect_uris'] = ['https://client.example/callback']
application.update!(confidential: true)
File.write(path, clients.to_yaml)
expect { registry.sync! }.to raise_error(ArgumentError, /only public clients/)
expect(application.reload.name).to eq('Renamed')
File.write(path, "--- !ruby/object:Object {}\n")
expect { registry.sync! }.to raise_error(Psych::DisallowedClass)
File.write(path, '{}')
expect(registry.sync!).to eq({})
expect(Doorkeeper::Application.count).to eq(1)
