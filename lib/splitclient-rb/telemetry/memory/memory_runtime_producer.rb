# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryRuntimeProducer < RuntimeProducer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def add_tag(tag)
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
        @storage.last_synchronization_records
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
    end
  end
end
