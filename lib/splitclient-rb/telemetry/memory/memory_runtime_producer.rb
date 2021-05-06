# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryRuntimeProducer < RuntimeProducer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def add_tag(tag)
        return if tag.length >= 9

        @storage.tags << tag
      end

      def record_impressions_stats(type, count)
        return if count.zero?

        impressions = @storage.impressions_data_records.find { |l| l[:type] == type }

        if impressions.nil?
          @storage.impressions_data_records << { type: type, value: count }
        else
          impressions[:value] += count
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_events_stats(type, count)
        return if count.zero?

        events = @storage.events_data_records.find { |l| l[:type] == type }

        if events.nil?
          @storage.events_data_records << { type: type, value: count }
        else
          events[:value] += count
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_successful_sync(type, timestamp)
        return if timestamp.zero?

        last_sync = @storage.last_synchronization_records.find { |l| l[:type] == type }

        if last_sync.nil?
          @storage.last_synchronization_records << { type: type, value: timestamp }
        else
          last_sync[:value] = timestamp
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_sync_error(type, status)
        http_errors = @storage.http_errors.find { |l| l[:type] == type }

        if http_errors.nil?
          value = Concurrent::Array.new
          value << { status: status, count: 1 }
          @storage.http_errors << { type: type, value: value }

          return
        end

        http_errors_value = http_errors[:value].find { |l| l[:status] == status }

        if http_errors_value.nil?
          http_errors[:value] << { status: status, count: 1 }
        else
          http_errors_value[:count] += 1
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_sync_latency(type, bucket)
        sync_latencies = @storage.http_latencies.find { |l| l[:type] == type }

        if sync_latencies.nil?
          latencies_array = Concurrent::Array.new
          latencies_array << bucket
          @storage.http_latencies << { type: type, value: latencies_array }
        else
          sync_latencies[:value] << bucket
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_auth_rejections
        @storage.auth_rejections.increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_token_refreshes
        @storage.token_refreshes.increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_streaming_event(type, data, timestamp)
        return if @storage.streaming_events.length >= 19

        event = StreamingEvent.new(type, data, timestamp)

        @storage.streaming_events << event
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_session_length(session)
        @storage.session_length.value = session
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
    end
  end
end
