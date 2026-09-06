# frozen_string_literal: true

# == Schema Information
#
# Table name: rubymcp_tasks
#
#  id           :string           not null, primary key
#  arguments    :text             not null
#  context_data :text             not null
#  expires_at   :datetime         not null
#  message      :text
#  owner        :string           not null
#  progress     :float
#  result       :text
#  status       :string           not null
#  tool_class   :string           not null
#  total        :float
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_rubymcp_tasks_on_expires_at  (expires_at)
#  index_rubymcp_tasks_on_owner       (owner)
#
module RubyMCP
  class Task < ActiveRecord::Base
    class Cancelled < StandardError; end

    self.table_name = 'rubymcp_tasks'

    serialize :arguments, coder: JSON
    serialize :context_data, coder: JSON
    serialize :result, coder: JSON

    def self.for_context!(id, context)
      owner = RubyMCP.configuration.task_owner.call(context)
      raise Tool::Error, 'Task not found' unless owner.is_a?(String) && owner.present?

      task = self.where(owner: owner).where('expires_at > ?', Time.current).find_by(id: id)
      raise Tool::Error, 'Task not found' unless task

      restored = RubyMCP.configuration.task_context_load.call(task.context_data)
      raise Tool::Error, 'Task not found' unless RubyMCP.configuration.task_owner.call(restored) == task.owner

      tool = Tool.available(context: restored).find { |candidate| candidate.name == task.tool_class }
      raise Tool::Error, 'Task not found' unless tool && tool.visible?(context: context)

      task
    end

    def snapshot
      {
        task_id: self.id, status: self.status, progress: self.progress, total: self.total,
        message: self.message, result: self.result, poll_after_seconds: 2
      }.compact
    end

    def report_progress!(progress, total: nil, message: nil)
      unless progress.is_a?(Numeric) && progress.finite? && progress >= 0 &&
          (total.nil? || (total.is_a?(Numeric) && total.finite? && total >= progress))
        raise ArgumentError, 'Progress must be finite, non-negative and no greater than total'
      end
      self.with_lock do
        raise Cancelled if self.status == 'cancelled' || self.expires_at <= Time.current
        raise ArgumentError, 'Progress cannot decrease' if self.progress && progress < self.progress

        self.update!(progress: progress, total: total, message: message) if self.status == 'working'
      end
    end

    def cancel!
      self.with_lock do
        self.update!(status: 'cancelled', message: 'Cancellation requested') if ['queued', 'working'].include?(self.status)
      end
    end
  end
end
