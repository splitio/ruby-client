# frozen_string_literal: true

require 'concurrent'

module SplitIoClient
  module SSE
    class NotificationManagerKeeper
      DISABLED = 0
      ENABLED = 1
      PAUSED = 2

      def initialize(config, telemetry_runtime_producer, status_queue)
        @config = config
        @telemetry_runtime_producer = telemetry_runtime_producer
        @status_queue = status_queue
        @publisher_available = Concurrent::AtomicBoolean.new(true)
        @publishers_pri = Concurrent::AtomicFixnum.new
        @publishers_sec = Concurrent::AtomicFixnum.new
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

      private

      def process_event_control(type)
        case type
        when 'STREAMING_PAUSED'
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::STREAMING_STATUS, PAUSED)
          push_status(Constants::PUSH_SUBSYSTEM_DOWN)
        when 'STREAMING_RESUMED'
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::STREAMING_STATUS, ENABLED)
          push_status(Constants::PUSH_SUBSYSTEM_READY) if @publisher_available.value
        when 'STREAMING_DISABLED'
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::STREAMING_STATUS, DISABLED)
          push_status(Constants::PUSH_SUBSYSTEM_OFF)
        else
          @config.logger.error("Incorrect event type: #{incoming_notification}")
        end
      end

      def process_event_occupancy(channel, publishers)
        @config.logger.debug("Processed occupancy event with #{publishers} publishers. Channel: #{channel}")

        update_publishers(channel, publishers)

        if !are_publishers_available? && @publisher_available.value
          @publisher_available.make_false
          push_status(Constants::PUSH_SUBSYSTEM_DOWN)
        elsif are_publishers_available? && !@publisher_available.value
          @publisher_available.make_true
          push_status(Constants::PUSH_SUBSYSTEM_READY)
        end
      end

      def update_publishers(channel, publishers)
        case channel
        when Constants::CONTROL_PRI
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::OCCUPANCY_PRI, publishers)
          @publishers_pri.value = publishers
        when Constants::CONTROL_SEC
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::OCCUPANCY_SEC, publishers)
          @publishers_sec.value = publishers
        end
      end

      def are_publishers_available?
        @publishers_pri.value.positive? || @publishers_sec.value.positive?
      end

      def push_status(status)
        @config.logger.debug("Pushing occupancy status: #{status}")
        @status_queue.push(status)
      end
    end
  end
end
