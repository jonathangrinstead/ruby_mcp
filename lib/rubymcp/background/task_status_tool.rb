# frozen_string_literal: true

module RubyMCP
  class TaskStatusTool < Tool
    tool_name 'rubymcp_task_status'
    description 'Check a background task for progress or its final result. Wait poll_after_seconds between checks.'
    param :task_id, type: :string, required: true

    def call(task_id:)
      Task.for_context!(task_id, self.context).snapshot
    end
  end
end
