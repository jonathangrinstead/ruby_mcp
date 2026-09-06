# frozen_string_literal: true

RSpec.describe RubyMCP::Tool do
  it 'builds independent inherited schemas with required and optional arguments' do
    parent = Class.new(RubyMCP::Tool)
    parent.description('An inherited description')
    parent.annotations(read_only_hint: true)
    parent.output_schema(properties: { name: { type: 'string' } }, required: ['name'])
    parent.param(:name, type: :string, required: true)
    child = Class.new(parent)
    child.param(:count, type: :integer, minimum: 1)

    expect(child.description).to eq('An inherited description')
    expect(child.annotations.read_only_hint).to eq(true)
    expect(child.output_schema.to_h).to eq(parent.output_schema.to_h)
    expect(child.input_schema.to_h[:required]).to eq(['name'])
    expect(child.input_schema.to_h[:properties]).to eq(name: { type: 'string' }, count: { minimum: 1, type: 'integer' })
    expect(parent.input_schema.to_h[:properties]).to eq(name: { type: 'string' })
    child.param(:name, type: :string)
    expect(child.input_schema.to_h[:required]).to eq([])
    expect(parent.input_schema.to_h[:required]).to eq(['name'])
  end

  it 'converts ordinary Ruby results and preserves explicit SDK responses' do
    tool = Class.new(RubyMCP::Tool)
    ['Hello', { amount: 12 }, [1, 2], false, nil].each do |value|
      tool.define_method(:call) { value }
      result = tool.call
      expect(result.content).to eq([{ type: 'text', text: value.is_a?(String) ? value : JSON.generate(value) }])
      expect(result.structured_content).to eq(value.is_a?(String) ? nil : value)
      expect(result.error?).to eq(false)
    end

    response = MCP::Tool::Response.new([{ type: 'text', text: 'Explicit' }])
    tool.define_method(:call) { response }
    expect(tool.call).to equal(response)
  end

  it 'keeps abstract status local to the base class' do
    base = Class.new(RubyMCP::Tool)
    base.abstract!
    expect(base.abstract?).to eq(true)
    expect(Class.new(base).abstract?).to eq(false)
  end
end
