# frozen_string_literal: true

module RubyMCP
  module ResourceContent
    def render_contents(result, uri:)
      if result.is_a?(MCP::Resource::Contents) || (result.is_a?(Array) && result.any? && result.all? { |item| item.is_a?(MCP::Resource::Contents) })
        result
      else
        MCP::Resource::TextContents.new(
          uri: uri,
          mime_type: self.mime_type || (result.is_a?(String) ? 'text/plain' : 'application/json'),
          text: result.is_a?(String) ? result : JSON.generate(result)
        )
      end
    end
  end
end
