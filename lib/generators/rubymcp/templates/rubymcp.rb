RubyMCP.configure do |config|
  config.name = Rails.application.class.module_parent_name.underscore

  # Add the hostname clients use, e.g. ['app.example.com'].
  config.allowed_hosts = []

  # Authenticate the request and return { current_account: account }, or nil to reject it.
  config.context = ->(_request) { nil }
end
