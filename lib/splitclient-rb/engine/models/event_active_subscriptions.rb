# frozen_string_literal: false

module SplitIoClient
  module Engine::Models
    class EventActiveSubscriptions
      attr_accessor :triggered, :handler

      def initialize(triggered, handler)
        @triggered = triggered
        @handler = handler
      end
    end
  end
end
