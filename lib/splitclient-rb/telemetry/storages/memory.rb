# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    module Storages
      class Memory
        attr_reader :latencies,
                    :exceptions,
                    :factory_counters,
                    :tags,
                    :impressions_data_records,
                    :events_data_records,
                    :last_synchronization_records

        def initialize
          @latencies = Concurrent::Array.new
          @exceptions = Concurrent::Array.new
          @factory_counters = Concurrent::Array.new
          @tags = Concurrent::Array.new
          @impressions_data_records = Concurrent::Array.new
          @events_data_records = Concurrent::Array.new
          @last_synchronization_records = Concurrent::Array.new
        end

        def clear_latencies
          @latencies = Concurrent::Array.new
        end

        def clear_exceptions
          @exceptions = Concurrent::Array.new
        end

        def clear_tags
          @tags = Concurrent::Array.new
        end
      end
    end
  end
end
