# frozen_string_literal: true

Rails.application.routes.draw do
  mount RubyMCP::Endpoint.new => '/mcp'
end
