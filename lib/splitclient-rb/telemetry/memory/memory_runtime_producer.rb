# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryRuntimeProducer < RuntimeProducer
      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def add_tag(tag)
        return if tag.length >= 9

        @adapter.tags << tag
      end

      def record_impressions_stats(type, count)
        @adapter.impressions_data_records.find { |l| l[:type] == type }[:value].value += count unless count.zero?
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_events_stats(type, count)
        @adapter.events_data_records.find { |l| l[:type] == type }[:value].value += count unless count.zero?
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_successful_sync(type, value = nil)
        value = (Time.now.to_f * 1000.0).to_i if value.nil?

        @adapter.last_synchronization.find { |l| l[:type] == type }[:value] = Concurrent::AtomicFixnum.new(value)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_sync_error(type, status)
        http_errors = @adapter.http_errors.find { |l| l[:type] == type }
        http_errors_value = http_errors[:value].find { |l| l[:status] == status }

        if http_errors_value.nil?
          http_errors[:value] << { status: status, count: Concurrent::AtomicFixnum.new(1) }
        else
          http_errors_value[:count].increment
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_sync_latency(type, bucket)
        @adapter.http_latencies.find { |l| l[:type] == type }[:value] << bucket
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_auth_rejections
        @adapter.auth_rejections.increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_token_refreshes
        @adapter.token_refreshes.increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_streaming_event(type, data, timestamp)
        @adapter.streaming_events << StreamingEvent.new(type, data, timestamp) unless @adapter.streaming_events.length >= 19
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_session_length(session)
        @adapter.session_length.value = session
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
    end
  end
end
