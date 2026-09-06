# frozen_string_literal: true

require 'sidekiq/testing'
Sidekiq::Testing.fake!
require "#{ARGV.fetch(0)}/config/application"
require 'rspec/expectations'
require 'rack/test'
include RSpec::Matchers

first = Account.create!(email: 'first@example.com', password: 'a-long-test-password')
second = Account.create!(email: 'second@example.com', password: 'a-long-test-password')
RubyMCP.configuration.context = lambda do |request|
  account = { 'Bearer first' => first, 'Bearer second' => second }[request.get_header('HTTP_AUTHORIZATION')]
  { current_account: account.reload } if account
end
session = Rack::Test::Session.new(Rails.application)
session.header('HOST', 'app.example.com')
session.header('X-Forwarded-Proto', 'https')
session.header('Authorization', 'Bearer first')
session.header('Accept', 'application/json, text/event-stream')
call_tool = lambda do |name, arguments|
  session.post('/mcp', JSON.generate(jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: name, arguments: arguments }), 'CONTENT_TYPE' => 'application/json')
  JSON.parse(session.last_response.body).fetch('result')
end
result = call_tool.call('research', {})
task_id = result.fetch('structuredContent').fetch('task_id')
expect(result.dig('structuredContent', 'status')).to eq('queued')
expect(Sidekiq::Queues['default'].last.fetch('args').first.fetch('arguments')).to eq([task_id])
expect(first.reload.failed_attempts).to eq(0)
Sidekiq::Job.drain_all
result = call_tool.call('rubymcp_task_status', task_id: task_id)
expect(result.dig('structuredContent', 'status')).to eq('completed')
expect(result.dig('structuredContent', 'progress')).to eq(2)
expect(result.dig('structuredContent', 'total')).to eq(2)
expect(result.dig('structuredContent', 'result', 'structuredContent')).to eq('email' => first.email)
RubyMCP::TaskExecuteJob.perform_now(task_id)
expect(first.reload.failed_attempts).to eq(1)
session.header('Authorization', 'Bearer second')
['rubymcp_task_status', 'rubymcp_task_cancel'].each do |tool|
  result = call_tool.call(tool, task_id: task_id)
  expect(result['isError']).to eq(true)
  expect(result.dig('content', 0, 'text')).to eq('Task not found')
end
session.header('Authorization', 'Bearer first')
failed_id = call_tool.call('research', fail: true).dig('structuredContent', 'task_id')
RubyMCP::TaskExecuteJob.perform_now(failed_id)
result = call_tool.call('rubymcp_task_status', task_id: failed_id)
expect(result.dig('structuredContent', 'status')).to eq('failed')
expect(result.to_s.include?('private-database-password')).to eq(false)
expect(result.dig('structuredContent', 'progress')).to eq(1)
expect(result.dig('structuredContent', 'message')).to eq('Background task failed')
cancelled_id = call_tool.call('research', {}).dig('structuredContent', 'task_id')
expect(call_tool.call('rubymcp_task_cancel', task_id: cancelled_id).dig('structuredContent', 'status')).to eq('cancelled')
RubyMCP::TaskExecuteJob.perform_now(cancelled_id)
expect(first.reload.failed_attempts).to eq(1)
revoked_id = call_tool.call('research', {}).dig('structuredContent', 'task_id')
first.update!(failed_attempts: 5)
RubyMCP::TaskExecuteJob.perform_now(revoked_id)
expect(RubyMCP::Task.find(revoked_id).status).to eq('failed')
expect(call_tool.call('rubymcp_task_status', task_id: task_id)['isError']).to eq(true)
first.update!(failed_attempts: 1)
locked_id = call_tool.call('research', {}).dig('structuredContent', 'task_id')
first.lock_access!(send_instructions: false)
RubyMCP::TaskExecuteJob.perform_now(locked_id)
expect(RubyMCP::Task.find(locked_id).status).to eq('failed')
first.unlock_access!
task = RubyMCP::Task.find(task_id)
task.update!(expires_at: 1.minute.ago)
expect(call_tool.call('rubymcp_task_status', task_id: task_id)['isError']).to eq(true)
progress_task = RubyMCP::Task.find(failed_id)
progress_task.update!(status: 'working')
expect { progress_task.report_progress!(0, total: 2) }.to raise_error(ArgumentError, /decrease/)
expect { progress_task.report_progress!(3, total: 2) }.to raise_error(ArgumentError, /no greater/)
progress_task.cancel!
expect { progress_task.report_progress!(2, total: 2) }.to raise_error(RubyMCP::Task::Cancelled)
Rails.application.load_tasks
Rake::Task['rubymcp:tasks:prune'].invoke
expect(RubyMCP::Task.exists?(task_id)).to eq(false)

['resources/list', 'resources/templates/list', 'prompts/list'].each do |method|
  session.post('/mcp', JSON.generate(jsonrpc: '2.0', id: 1, method: method), 'CONTENT_TYPE' => 'application/json')
  expect(JSON.parse(session.last_response.body)['result'].values.first.length).to eq(1)
end

require 'rspec/mocks/standalone'
allow(RubyMCP::TaskExecuteJob).to receive(:perform_later).and_return(false)
result = call_tool.call('research', {})
expect(result['isError']).to eq(true)
expect(RubyMCP::Task.order(:created_at).last.status).to eq('failed')
expect(result.dig('content', 0, 'text')).to eq('Could not enqueue background task')
