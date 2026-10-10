# frozen_string_literal: true

require 'uri'

module RubyMCP
  class DeviseAuthentication
    attr_reader :model_name, :issuer, :resource

    def initialize(model:, issuer:)
      uri = URI.parse(issuer)
      local_http = uri.scheme == 'http' && ['localhost', '127.0.0.1', '::1'].include?(uri.hostname)
      unless uri.host && (uri.scheme == 'https' || local_http) && ['', '/'].include?(uri.path) &&
          uri.query.nil? && uri.fragment.nil? && uri.userinfo.nil?
        raise ArgumentError, 'Issuer must be an HTTPS origin (HTTP is allowed on localhost)'
      end

      @model_name = model
      @issuer = issuer.delete_suffix('/')
      @resource = "#{self.issuer}/mcp"
    end

    def call(request)
      scheme, secret = request.get_header('HTTP_AUTHORIZATION').to_s.split(' ', 2)
      token = Doorkeeper::AccessToken.by_token(secret) if scheme&.casecmp?('Bearer') && secret.present?
      unless token&.accessible? && token.resource.to_s.split.include?(self.resource)
        self.reject!(:unauthorized, secret.present? ? 'invalid_token' : nil)
      end

      self.reject!(:forbidden, 'insufficient_scope') if token.scopes.exclude?('mcp')
      account = self.model_name.constantize.find_by(id: token.resource_owner_id)
      self.reject!(:unauthorized, 'invalid_token') unless account&.active_for_authentication?
      token.revoke_previous_refresh_token!

      { current_account: account }
    end

    def metadata(_env)
      [Rack::Utils.status_code(:ok), { 'content-type' => 'application/json' }, [JSON.generate(
        resource: self.resource,
        authorization_servers: [self.issuer],
        scopes_supported: ['mcp'],
        bearer_methods_supported: ['header']
      )]]
    end

    private

    def reject!(status, error)
      challenge = "Bearer resource_metadata=\"#{self.issuer}/.well-known/oauth-protected-resource/mcp\", scope=\"mcp\""
      challenge += ", error=\"#{error}\"" if error
      raise AuthenticationError.new(status: status, challenge: challenge)
    end
  end
end
