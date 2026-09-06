# frozen_string_literal: true

require 'bundler/setup'
require 'rubymcp'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
