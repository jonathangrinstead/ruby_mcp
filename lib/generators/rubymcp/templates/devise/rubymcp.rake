namespace :rubymcp do
  desc 'Register an MCP client: NAME=Claude REDIRECT_URI=https://client.example/callback'
  task register_client: :environment do
    name = ENV.fetch('NAME')
    redirect_uri = ENV.fetch('REDIRECT_URI')
    uri = URI.parse(redirect_uri)
    unless uri.scheme == 'https' && uri.host && uri.fragment.nil? && uri.userinfo.nil?
      abort 'REDIRECT_URI must be the exact HTTPS callback URL supplied by the MCP client'
    end

    application = Doorkeeper::Application.find_or_create_by!(name: name, redirect_uri: redirect_uri, confidential: false, scopes: 'mcp')
    puts "Client ID: #{application.uid}"
    puts 'This public client uses PKCE; no client secret is needed.'
  end
end
