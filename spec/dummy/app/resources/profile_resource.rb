# frozen_string_literal: true

class ProfileResource < RubyMCP::Resource
  uri 'app://profile'

  def self.visible?(context:)
    context.fetch(:current_account) == 'first'
  end

  def call
    { account: self.current_account }
  end
end
