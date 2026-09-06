# frozen_string_literal: true

module RubyMCP
  class AuthenticationError < StandardError
    attr_reader :status, :challenge

    def initialize(status:, challenge:)
      @status = status
      @challenge = challenge
      super(status == :forbidden ? 'Insufficient scope' : 'Unauthorised')
    end
  end
end
