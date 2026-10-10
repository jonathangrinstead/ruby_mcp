RSpec.describe RubyMCP::AuthenticationError do
  it 'preserves the bearer challenge and distinguishes missing access from insufficient scope' do
    challenge = 'Bearer resource_metadata="https://app.example.com/.well-known/oauth-protected-resource/mcp"'
    error = RubyMCP::AuthenticationError.new(status: :unauthorized, challenge: challenge)
    expect(error.status).to eq(:unauthorized)
    expect(error.challenge).to eq(challenge)
    expect(error.message).to eq('Unauthorised')

    error = RubyMCP::AuthenticationError.new(status: :forbidden, challenge: challenge)
    expect(error.status).to eq(:forbidden)
    expect(error.challenge).to eq(challenge)
    expect(error.message).to eq('Insufficient scope')
  end
end
