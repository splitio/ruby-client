# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryRuntimeConsumer
      DEFAULT_VALUE = 0

      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def pop_tags
        to_return = @adapter.tags

        @adapter.init_tags

        to_return
      end

      def impressions_stats(type)
        @adapter.impressions_data_records.find { |l| l[:type] == type }[:value].value
      end

      def events_stats(type)
        @adapter.events_data_records.find { |l| l[:type] == type }[:value].value
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

        @adapter.init_http_errors

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

        @adapter.init_http_latencies

        HttpLatencies.new(splits, segments, impressions, imp_count, events, telemetry, token)
      end

      def pop_auth_rejections
        to_return = @adapter.auth_rejections

        @adapter.init_auth_rejections

        to_return.value
      end

      def pop_token_refreshes
        to_return = @adapter.token_refreshes

        @adapter.init_token_refreshes

        to_return.value
      end

      def pop_streaming_events
        events = @adapter.streaming_events

        @adapter.init_streaming_events.map

        events
      end

      def session_length
        @adapter.session_length.value
      end

      private

      def find_last_synchronization(type)
        @adapter.last_synchronization.find { |l| l[:type] == type }[:value].value
      end

      def find_http_errors(type)
        @adapter.http_errors.find { |l| l[:type] == type }[:value]
      end

      def find_http_latencies(type)
        @adapter.http_latencies.find { |l| l[:type] == type }[:value]
      end
    end
  end
end
