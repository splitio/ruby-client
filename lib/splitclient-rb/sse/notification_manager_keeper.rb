# frozen_string_literal: true

require 'concurrent/atomics'

module SplitIoClient
  module SSE
    class NotificationManagerKeeper
      def initialize(config)
        @config = config
        @polling_on = Concurrent::AtomicBoolean.new(false)
        @on = { occupancy: ->(_) {} }

        yield self if block_given?
      end

      def handle_incoming_occupancy_event(event)
        process_event(event.data['metrics']['publishers']) unless event.channel == 'control_pri'
      rescue StandardError => e
        @config.logger.error(e)
      end

      def on_occupancy(&action)
        @on[:occupancy] = action
      end

      private

      def process_event(publishers)
        if publishers <= 0 && !@polling_on.value
          @polling_on.make_true
          dispatch_occupancy_event(false)
        elsif publishers >= 1 && @polling_on.value
          @polling_on.make_false
          dispatch_occupancy_event(true)
        end
      end

      def dispatch_occupancy_event(publisher_available)
        @config.logger.debug("Dispatching occupancy event with publisher avaliable: #{publisher_available}")
        @on[:occupancy].call(publisher_available)
      end
    end
  end
end
