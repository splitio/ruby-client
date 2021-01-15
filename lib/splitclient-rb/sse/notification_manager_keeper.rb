# frozen_string_literal: true

require 'concurrent'

module SplitIoClient
  module SSE
    class NotificationManagerKeeper
      def initialize(config)
        @config = config
        @streaming_available = Concurrent::AtomicBoolean.new(true)
        @publishers_pri = Concurrent::AtomicFixnum.new
        @publishers_sec = Concurrent::AtomicFixnum.new
        @on = { occupancy: ->(_) {}, push_shutdown: ->(_) {} }

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

      def on_occupancy(&action)
        @on[:occupancy] = action
      end

      def on_push_shutdown(&action)
        @on[:push_shutdown] = action
      end

      private

      def process_event_control(type)
        case type
        when 'STREAMING_PAUSED'
          dispatch_occupancy_event(false)
        when 'STREAMING_RESUMED'
          dispatch_occupancy_event(true) if @streaming_available.value
        when 'STREAMING_DISABLED'
          dispatch_push_shutdown
        else
          @config.logger.error("Incorrect event type: #{incoming_notification}")
        end
      end

      def process_event_occupancy(channel, publishers)
        @config.logger.debug("Occupancy process event with #{publishers} publishers. Channel: #{channel}")

        update_publishers(channel, publishers)

        if !are_publishers_avaliable? && @streaming_available.value
          @streaming_available.make_false
          dispatch_occupancy_event(false)
        elsif are_publishers_avaliable? && !@streaming_available.value
          @streaming_available.make_true
          dispatch_occupancy_event(true)
        end
      end

      def update_publishers(channel, publishers)
        @publishers_pri.compare_and_set(@publishers_pri.value, publishers) if channel == SplitIoClient::Constants::CONTROL_PRI
        @publishers_sec.compare_and_set(@publishers_sec.value, publishers) if channel == SplitIoClient::Constants::CONTROL_SEC
      end

      def are_publishers_avaliable?
        @publishers_pri.value.positive? || @publishers_sec.value.positive?
      end

      def dispatch_occupancy_event(push_enable)
        @config.logger.debug("Dispatching occupancy event with publisher avaliable: #{push_enable}")
        @on[:occupancy].call(push_enable)
      end

      def dispatch_push_shutdown
        @config.logger.debug('Dispatching push shutdown')
        @on[:push_shutdown].call
      end
    end
  end
end
