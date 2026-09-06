# frozen_string_literal: true

module RubyMCP
  class TaskCancelTool < Tool
    tool_name 'rubymcp_task_cancel'
    description 'Request cancellation of your background task. Work already performed cannot be undone.'
    param :task_id, type: :string, required: true

    def call(task_id:)
      task = Task.for_context!(task_id, self.context)
      task.cancel!
      task.snapshot
    end
  end
end
