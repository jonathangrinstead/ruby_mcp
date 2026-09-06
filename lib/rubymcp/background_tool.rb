# frozen_string_literal: true

module RubyMCP
  class BackgroundTool < Tool
    abstract!

    def self.call(server_context: {}, **arguments)
      configuration = RubyMCP.configuration
      owner = configuration.task_owner.call(server_context)
      raise Error, 'Background tasks require an authenticated owner' unless owner.is_a?(String) && owner.present?
      raise Error, 'Tool is unavailable' unless self.visible?(context: server_context)
      raise Error, 'Background tools cannot be enqueued inside a database transaction' if Task.connection.transaction_open?

      task = Task.new(
        id: SecureRandom.uuid, owner: owner, tool_class: self.name, arguments: arguments,
        context_data: configuration.task_context_dump.call(server_context), status: 'queued', expires_at: 24.hours.from_now
      )
      self.output_schema&.validate_result(task.snapshot)
      task.save!
      begin
        job = TaskExecuteJob.perform_later(task.id)
        raise Error, 'Could not enqueue background task' unless job
      rescue StandardError
        task.update!(status: 'failed', message: 'Could not enqueue background task')
        raise
      end
      self.response(task.reload.snapshot)
    rescue Error => exception
      MCP::Tool::Response.new([{ type: 'text', text: exception.message }], error: true)
    end

    def initialize(context: {}, task: nil)
      super(context: context)
      @task = task
    end

    def report_progress(progress, total: nil, message: nil)
      @task.report_progress!(progress, total: total, message: message)
    end
  end
end
