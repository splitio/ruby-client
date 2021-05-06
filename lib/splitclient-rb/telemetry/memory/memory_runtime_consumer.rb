# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryRuntimeConsumer < RuntimeConsumer
      DEFAULT_VALUE = 0

      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def pop_tags
        to_return = @storage.tags

        @storage.clear_tags

        to_return
      end

      def impressions_stats(type)
        stats = @storage.impressions_data_records.find { |l| l[:type] == type }

        return stats[:value] unless stats.nil?

        DEFAULT_VALUE
      end

      def events_stats(type)
        stats = @storage.events_data_records.find { |l| l[:type] == type }

        return stats[:value] unless stats.nil?

        DEFAULT_VALUE
      end

      def last_synchronizations
        splits = find_last_synchronization(Domain::Constants::SPLIT_SYNC)
        segments = find_last_synchronization(Domain::Constants::SEGMENT_SYNC)
        impressions = find_last_synchronization(Domain::Constants::IMPRESSIONS_SYNC)
        imp_count = find_last_synchronization(Domain::Constants::IMPRESSION_COUNT_SYNC)
        events = find_last_synchronization(Domain::Constants::EVENT_SYNC)
        telemetry = find_last_synchronization(Domain::Constants::TELEMETRY_SYNC)
        token = find_last_synchronization(Domain::Constants::TOKEN_SYNC)

        LastSynchronization.new(splits, segments, impressions, imp_count, events, telemetry, token)
      end

      def pop_http_errors
        splits = find_http_errors(Domain::Constants::SPLIT_SYNC)
        segments = find_http_errors(Domain::Constants::SEGMENT_SYNC)
        impressions = find_http_errors(Domain::Constants::IMPRESSIONS_SYNC)
        imp_count = find_http_errors(Domain::Constants::IMPRESSION_COUNT_SYNC)
        events = find_http_errors(Domain::Constants::EVENT_SYNC)
        telemetry = find_http_errors(Domain::Constants::TELEMETRY_SYNC)
        token = find_http_errors(Domain::Constants::TOKEN_SYNC)

        @storage.clear_http_errors

        HttpErrors.new(splits, segments, impressions, imp_count, events, telemetry, token)
      end

      def pop_http_latencies
        splits = find_http_latencies(Domain::Constants::SPLIT_SYNC)
        segments = find_http_latencies(Domain::Constants::SEGMENT_SYNC)
        impressions = find_http_latencies(Domain::Constants::IMPRESSIONS_SYNC)
        imp_count = find_http_latencies(Domain::Constants::IMPRESSION_COUNT_SYNC)
        events = find_http_latencies(Domain::Constants::EVENT_SYNC)
        telemetry = find_http_latencies(Domain::Constants::TELEMETRY_SYNC)
        token = find_http_latencies(Domain::Constants::TOKEN_SYNC)

        @storage.clear_http_latencies

        HttpLatencies.new(splits, segments, impressions, imp_count, events, telemetry, token)
      end

      def pop_auth_rejections
        to_return = @storage.auth_rejections

        @storage.clear_auth_rejections

        to_return.value
      end

      def pop_token_refreshes
        to_return = @storage.token_refreshes

        @storage.clear_token_refreshes

        to_return.value
      end

      def pop_streaming_events
        events = @storage.streaming_events

        @storage.clear_streaming_events

        events
      end

      def session_length
        @storage.session_length.value
      end

      private

      def find_last_synchronization(type)
        last_sync = @storage.last_synchronization_records.find { |l| l[:type] == type }

        return last_sync[:value] unless last_sync.nil?

        DEFAULT_VALUE
      end

      def find_http_errors(type)
        errors = @storage.http_errors.find { |l| l[:type] == type }

        return errors[:value] unless errors.nil?

        []
      end

      def find_http_latencies(type)
        latencies = @storage.http_latencies.find { |l| l[:type] == type }

        return latencies[:value] unless latencies.nil?

        []
      end
    end
  end
end
