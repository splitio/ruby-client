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
    end
  end
end
