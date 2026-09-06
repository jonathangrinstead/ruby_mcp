# frozen_string_literal: true

class FailureTool < ApplicationTool
  description 'Exercise expected and unexpected failures'
  param :expected, type: :boolean, required: true

  def call(expected:)
    if expected
      raise RubyMCP::Tool::Error, 'Invoice is already paid'
    else
      raise 'private-database-password'
    end
  end
end
