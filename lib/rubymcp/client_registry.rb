# frozen_string_literal: true

require 'yaml'
require 'uri'

module RubyMCP
  class ClientRegistry
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def sync!
      definitions = self.definitions
      Doorkeeper::Application.transaction do
        definitions.to_h do |key, attributes|
          existing_id = attributes['client_id']
          client_id = existing_id || "rubymcp_#{key}"
          application = Doorkeeper::Application.find_by(uid: client_id)
          raise ArgumentError, "#{key}: client_id does not match an existing client" if existing_id && application.nil?

          if application && (application.confidential? || application.scopes.to_s != 'mcp')
            raise ArgumentError, "#{key}: only public clients with the mcp scope can be managed"
          end

          application ||= Doorkeeper::Application.new(uid: client_id, confidential: false, scopes: 'mcp')
          application.assign_attributes(name: attributes.fetch('name'), redirect_uri: attributes.fetch('redirect_uris').uniq.join("\n"))
          application.save! if application.new_record? || application.changed?
          [key, application.uid]
        end
      end
    end

    private

    def definitions
      definitions = YAML.safe_load_file(self.path, permitted_classes: [], permitted_symbols: [], aliases: false)
      raise ArgumentError, 'rubymcp_clients.yml must contain a mapping of client keys' unless definitions.is_a?(Hash)

      definitions.each do |key, attributes|
        unless key.is_a?(String) && key.match?(/\A[a-z][a-z0-9_-]*\z/) && attributes.is_a?(Hash)
          raise ArgumentError, 'Each client needs a lowercase key and a mapping of attributes'
        end

        unless (attributes.keys - ['name', 'redirect_uris', 'client_id']).empty?
          raise ArgumentError, "#{key}: unknown client settings"
        end

        unless attributes['name'].is_a?(String) && !attributes['name'].strip.empty?
          raise ArgumentError, "#{key}: name must be a non-empty string"
        end

        if attributes.key?('client_id') && (!attributes['client_id'].is_a?(String) || attributes['client_id'].strip.empty?)
          raise ArgumentError, "#{key}: client_id must be a non-empty string"
        end

        urls = attributes['redirect_uris']
        raise ArgumentError, "#{key}: redirect_uris must be a non-empty array" unless urls.is_a?(Array) && urls.any?

        urls.each do |url|
          uri = url.is_a?(String) ? URI.parse(url) : nil
          unless uri&.scheme == 'https' && uri.host && uri.fragment.nil? && uri.userinfo.nil? && url.exclude?('*')
            raise ArgumentError, "#{key}: callbacks must be exact HTTPS URLs without credentials, fragments or wildcards"
          end
        end
      end

      identifiers = definitions.collect { |key, attributes| attributes['client_id'] || "rubymcp_#{key}" }
      raise ArgumentError, 'Two entries cannot manage the same client ID' unless identifiers.uniq == identifiers

      definitions
    end
  end
end
