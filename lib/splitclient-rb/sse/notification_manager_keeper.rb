# frozen_string_literal: true

require 'concurrent'

module SplitIoClient
  module SSE
    class NotificationManagerKeeper
      def initialize(config)
        @config = config
        @publisher_available = Concurrent::AtomicBoolean.new(true)
        @publishers_pri = Concurrent::AtomicFixnum.new
        @publishers_sec = Concurrent::AtomicFixnum.new
        @on = { action: ->(_) {} }

        yield self if block_given?
      end

      def handle_incoming_occupancy_event(event)
        if event.data['type'] == 'CONTROL'
          process_event_control(event.data['controlType'])
        else
          process_event_occupancy(event.channel, event.data['metrics']['publishers'])
        end
      rescue StandardError => e
        @config.logger.error(e)
      end

      def on_action(&action)
        @on[:action] = action
      end

      private

      def process_event_control(type)
        case type
        when 'STREAMING_PAUSED'
          dispatch_action(Constants::PUSH_SUBSYSTEM_DOWN)
        when 'STREAMING_RESUMED'
          dispatch_action(Constants::PUSH_SUBSYSTEM_READY) if @publisher_available.value
        when 'STREAMING_DISABLED'
          dispatch_action(Constants::PUSH_SUBSYSTEM_OFF)
        else
          @config.logger.error("Incorrect event type: #{incoming_notification}")
        end
      end

      def process_event_occupancy(channel, publishers)
        @config.logger.debug("Processed occupancy event with #{publishers} publishers. Channel: #{channel}")

        update_publishers(channel, publishers)

        if !are_publishers_available? && @publisher_available.value
          @publisher_available.make_false
          dispatch_action(Constants::PUSH_SUBSYSTEM_DOWN)
        elsif are_publishers_available? && !@publisher_available.value
          @publisher_available.make_true
          dispatch_action(Constants::PUSH_SUBSYSTEM_READY)
        end
      end

      def update_publishers(channel, publishers)
        @publishers_pri.value = publishers if channel == Constants::CONTROL_PRI
        @publishers_sec.value = publishers if channel == Constants::CONTROL_SEC
      end

      def are_publishers_available?
        @publishers_pri.value.positive? || @publishers_sec.value.positive?
      end

      def dispatch_action(action)
        @config.logger.debug("Dispatching action: #{action}")
        @on[:action].call(action)
      end
    end
  end
end
