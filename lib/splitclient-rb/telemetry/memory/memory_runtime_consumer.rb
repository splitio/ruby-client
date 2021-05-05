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

      private

      def find_last_synchronization(type)
        last_sync = @storage.last_synchronization_records.find { |l| l[:type] == type }

        return last_sync[:value] unless last_sync.nil?

        DEFAULT_VALUE
      end
    end
  end
end
