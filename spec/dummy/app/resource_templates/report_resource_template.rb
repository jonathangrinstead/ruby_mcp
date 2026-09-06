# frozen_string_literal: true

class ReportResourceTemplate < RubyMCP::ResourceTemplate
  uri_template 'app://reports/{id}'

  def self.visible?(context:)
    context.fetch(:current_account) == 'first'
  end

  def call(id:)
    { id: id, account: self.current_account }
  end
end
