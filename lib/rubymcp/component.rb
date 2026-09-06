# frozen_string_literal: true

module RubyMCP
  module Component
    extend ActiveSupport::Concern

    included do
      extend ActiveSupport::DescendantsTracker
      attr_reader :context
    end

    class_methods do
      def abstract!
        @abstract = true
      end

      def abstract?
        @abstract == true
      end

      def visible?(context:)
        true
      end

      def available(context:)
        self.descendants.select { |component| component.name && !component.abstract? && component.visible?(context: context) }.sort_by(&:name_value)
      end
    end

    def initialize(context: {})
      @context = context
    end

    def current_account
      self.context.fetch(:current_account)
    end
  end
end
