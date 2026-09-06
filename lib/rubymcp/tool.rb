# frozen_string_literal: true

module RubyMCP
  class Tool < MCP::Tool
    include Component

    class Error < StandardError; end

    def self.inherited(subclass)
      super
      subclass.title(self.title)
      subclass.description(self.description)
      subclass.input_schema(self.input_schema.to_h.deep_dup)
      subclass.output_schema(self.output_schema.to_h.deep_dup) if self.output_schema
      if self.annotations
        subclass.annotations(self.annotations.to_h.transform_keys { |key| key.to_s.underscore.to_sym })
      end
    end

    def self.name_value
      @name_value || self.name&.delete_suffix('Tool')&.underscore&.tr('/', '_')
    end

    def self.param(name, type:, required: false, **options)
      schema = self.input_schema.to_h.deep_dup
      schema[:properties] ||= {}
      schema[:required] ||= []
      schema[:properties][name.to_sym] = options.merge(type: type.to_s)
      schema[:required].delete(name.to_s)
      schema[:required] << name.to_s if required
      schema[:additionalProperties] = false
      self.input_schema(schema)
    end

    def self.call(server_context: {}, **arguments)
      self.response(self.new(context: server_context).call(**arguments))
    rescue Error => exception
      MCP::Tool::Response.new([{ type: 'text', text: exception.message }], error: true)
    end

    def self.response(result)
      case result
      when MCP::Tool::Response
        result
      when String
        MCP::Tool::Response.new([{ type: 'text', text: result }])
      else
        MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(result) }], structured_content: result)
      end
    end

  end
end
