# frozen_string_literal: false

module SplitIoClient
  module Engine::Models
    class EventsActiveSubscriptions
      attr_reader :triggered, :handler

      def initialize(triggered, handler)
        @triggered = triggered
        @handler = handler
      end
    end
  end
end
