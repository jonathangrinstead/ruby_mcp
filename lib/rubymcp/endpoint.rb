# frozen_string_literal: true

require 'rack'

module RubyMCP
  class Endpoint
    def call(env)
      configuration = RubyMCP.configuration
      context = configuration.context.call(Rack::Request.new(env))

      if context.nil? || context == false
        [Rack::Utils.status_code(:unauthorized), { 'content-type' => 'application/json' }, [JSON.generate(error: 'Unauthorised')]]
      else
        raise ArgumentError, 'RubyMCP context must return a Hash or nil' unless context.is_a?(Hash)

        self.transport(configuration, context).call(env)
      end
    rescue AuthenticationError => exception
      [
        Rack::Utils.status_code(exception.status),
        { 'content-type' => 'application/json', 'www-authenticate' => exception.challenge, 'cache-control' => 'no-store' },
        [JSON.generate(error: exception.message)]
      ]
    end

    private

    def transport(configuration, context)
      server = MCP::Server.new(
        name: configuration.name,
        version: configuration.version,
        instructions: configuration.instructions,
        tools: Tool.available(context: context),
        capabilities: { tools: {} },
        server_context: context,
        configuration: MCP::Configuration.new(
          validate_tool_call_results: true,
          exception_reporter: ->(exception, _context) { Rails.error.report(exception) }
        )
      )

      MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        allowed_hosts: configuration.allowed_hosts,
        allowed_origins: configuration.allowed_origins
      )
    end
  end
end
