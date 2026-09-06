# frozen_string_literal: true

module RubyMCP
  class Configuration
    attr_accessor :name, :version, :instructions, :context, :allowed_hosts, :allowed_origins

    attr_accessor :task_owner, :task_context_dump, :task_context_load

    def initialize
      @name = 'rails_app'
      @version = '1.0.0'
      @allowed_hosts = []
      @allowed_origins = []
      @context = ->(_request) { nil }
    end
  end
end
