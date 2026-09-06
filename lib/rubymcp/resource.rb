# frozen_string_literal: true

module RubyMCP
  class Resource < MCP::Resource
    include Component
    extend ResourceContent

    def self.inherited(subclass)
      super
      subclass.uri(self.uri)
      subclass.description(self.description)
      subclass.mime_type(self.mime_type)
    end

    def self.name_value
      @name_value || self.name&.delete_suffix('Resource')&.underscore&.tr('/', '_')
    end

    def self.contents(server_context: {})
      self.render_contents(self.new(context: server_context).call, uri: self.uri)
    end
  end
end
