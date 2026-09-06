# frozen_string_literal: true

module RubyMCP
  class Prompt < MCP::Prompt
    include Component

    def self.inherited(subclass)
      super
      subclass.title(self.title)
      subclass.description(self.description)
      subclass.arguments(self.arguments.deep_dup)
    end

    def self.name_value
      @name_value || self.name&.delete_suffix('Prompt')&.underscore&.tr('/', '_')
    end

    def self.param(name, required: false, description: nil)
      self.arguments(self.arguments.reject { |argument| argument.name == name.to_s } + [
        MCP::Prompt::Argument.new(name: name.to_s, required: required, description: description)
      ])
    end

    def self.template(arguments, server_context: {})
      arguments ||= {}
      unless arguments.keys.collect(&:to_s).all? { |name| self.arguments.any? { |argument| argument.name == name } } && arguments.values.all? { |value| value.is_a?(String) }
        raise MCP::Server::RequestHandlerError.new('Prompt arguments must be declared strings', nil, error_code: -32_602)
      end
      result = self.new(context: server_context).call(**arguments.transform_keys(&:to_sym))
      if result.is_a?(MCP::Prompt::Result)
        result
      else
        messages = result.is_a?(String) ? [MCP::Prompt::Message.new(role: 'user', content: { type: 'text', text: result })] : result
        MCP::Prompt::Result.new(description: self.description, messages: messages)
      end
    end
  end
end
