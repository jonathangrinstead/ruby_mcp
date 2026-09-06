# frozen_string_literal: true

RSpec.describe RubyMCP::Configuration do
  it 'rejects requests until an application supplies context and keeps settings independent' do
    configuration = RubyMCP::Configuration.new
    expect(configuration.context.call(nil)).to be_nil
    expect(configuration.allowed_hosts).to eq([])
    configuration.allowed_hosts << 'app.example.com'
    expect(RubyMCP::Configuration.new.allowed_hosts).to eq([])
  end
end
