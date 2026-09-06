# frozen_string_literal: true

class GreetingTool < ApplicationTool
  description 'Greet someone on behalf of the authenticated account'
  param :name, type: :string, required: true
  param :punctuation, type: :string
  output_schema(
    properties: { message: { type: 'string' }, account: { type: 'string' }, calls: { type: 'integer' } },
    required: ['message', 'account', 'calls']
  )

  def call(name:, punctuation: '!')
    @calls = (@calls || 0) + 1
    { message: "Hello, #{name}#{punctuation}", account: self.current_account, calls: @calls }
  end
end
