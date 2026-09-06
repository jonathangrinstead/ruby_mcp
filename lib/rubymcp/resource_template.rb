# frozen_string_literal: true

module RubyMCP
  class ResourceTemplate < MCP::ResourceTemplate
    include Component
    extend ResourceContent

    def self.inherited(subclass)
      super
      subclass.uri_template(self.uri_template)
      subclass.description(self.description)
      subclass.mime_type(self.mime_type)
    end

    def self.name_value
      @name_value || self.name&.delete_suffix('ResourceTemplate')&.underscore&.tr('/', '_')
    end

    def self.contents(server_context: {}, **parameters)
      uri = self.uri_template.gsub(/\{([A-Za-z_]\w*)\}/) { parameters.fetch(Regexp.last_match(1).to_sym) }
      self.render_contents(self.new(context: server_context).call(**parameters), uri: uri)
    end
  end
end
