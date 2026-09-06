# frozen_string_literal: true

class ComparisonPrompt < RubyMCP::Prompt
  param :first, required: true
  param :second, required: true

  def self.visible?(context:)
    context.fetch(:current_account) == 'first'
  end

  def call(first:, second:)
    "Compare #{first} and #{second} for #{self.current_account}."
  end
end
