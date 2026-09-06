# frozen_string_literal: true

module RubyMCP
  class TaskExecuteJob < ActiveJob::Base
    queue_as :default

    def perform(task_id)
      task = Task.find_by(id: task_id)
      if task
        claimed = task.with_lock do
          task.update!(status: 'working') if task.status == 'queued' && task.expires_at > Time.current
        end
        if claimed
          context = RubyMCP.configuration.task_context_load.call(task.context_data)
          raise Tool::Error, 'Task is no longer authorised' unless RubyMCP.configuration.task_owner.call(context) == task.owner

          tool = BackgroundTool.available(context: context).find { |candidate| candidate.name == task.tool_class }
          raise Tool::Error, 'Task is no longer authorised' unless tool

          arguments = task.arguments.deep_symbolize_keys
          tool.input_schema.validate_arguments(arguments)
          result = tool.new(context: context, task: task).call(**arguments)
          response = Tool.response(result)
          task.with_lock do
            task.update!(status: response.error? ? 'failed' : 'completed', result: response.to_h) if task.status == 'working'
          end
        end
      end
    rescue Task::Cancelled
      task.cancel!
    rescue StandardError => exception
      Rails.error.report(exception)
      task&.with_lock do
        if task.status == 'working'
          task.update!(status: 'failed', message: exception.is_a?(Tool::Error) ? exception.message : 'Background task failed')
        end
      end
    end
  end
end
