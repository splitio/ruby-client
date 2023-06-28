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
                    :last_synchronization,
                    :http_errors,
                    :http_latencies,
                    :auth_rejections,
                    :token_refreshes,
                    :streaming_events,
                    :session_length,
                    :updates_from_sse

        def initialize
          init_latencies
          init_exceptions
          init_factory_counters
          init_impressions_data_records
          init_events_data_records
          init_last_synchronization
          init_http_errors
          init_http_latencies
          init_auth_rejections
          init_token_refreshes
          init_streaming_events
          init_session_length
          init_tags
          init_updates_from_sse
        end

        def init_latencies
          @latencies = Concurrent::Array.new

          array_size = BinarySearchLatencyTracker::BUCKETS.length
          @latencies << { method: Domain::Constants::TREATMENT, latencies: Concurrent::Array.new(array_size, 0) }
          @latencies << { method: Domain::Constants::TREATMENTS, latencies: Concurrent::Array.new(array_size, 0) }
          @latencies << { method: Domain::Constants::TREATMENT_WITH_CONFIG, latencies: Concurrent::Array.new(array_size, 0) }
          @latencies << { method: Domain::Constants::TREATMENTS_WITH_CONFIG, latencies: Concurrent::Array.new(array_size, 0) }
          @latencies << { method: Domain::Constants::TRACK, latencies: Concurrent::Array.new(array_size, 0) }
        end

        def init_exceptions
          @exceptions = Concurrent::Array.new

          @exceptions << { method: Domain::Constants::TREATMENT, exceptions: Concurrent::AtomicFixnum.new(0) }
          @exceptions << { method: Domain::Constants::TREATMENTS, exceptions: Concurrent::AtomicFixnum.new(0) }
          @exceptions << { method: Domain::Constants::TREATMENT_WITH_CONFIG, exceptions: Concurrent::AtomicFixnum.new(0) }
          @exceptions << { method: Domain::Constants::TREATMENTS_WITH_CONFIG, exceptions: Concurrent::AtomicFixnum.new(0) }
          @exceptions << { method: Domain::Constants::TRACK, exceptions: Concurrent::AtomicFixnum.new(0) }
        end

        def init_factory_counters
          @factory_counters = Concurrent::Array.new

          @factory_counters << { action: Domain::Constants::BUR_TIMEOUT, counts: Concurrent::AtomicFixnum.new(0) }
          @factory_counters << { action: Domain::Constants::NON_READY_USAGES, counts: Concurrent::AtomicFixnum.new(0) }
        end

        def init_impressions_data_records
          @impressions_data_records = Concurrent::Array.new

          @impressions_data_records << { type: Domain::Constants::IMPRESSIONS_DEDUPE, value: Concurrent::AtomicFixnum.new(0) }
          @impressions_data_records << { type: Domain::Constants::IMPRESSIONS_DROPPED, value: Concurrent::AtomicFixnum.new(0) }
          @impressions_data_records << { type: Domain::Constants::IMPRESSIONS_QUEUED, value: Concurrent::AtomicFixnum.new(0) }
        end

        def init_events_data_records
          @events_data_records = Concurrent::Array.new

          @events_data_records << { type: Domain::Constants::EVENTS_DROPPED, value: Concurrent::AtomicFixnum.new(0) }
          @events_data_records << { type: Domain::Constants::EVENTS_QUEUED, value: Concurrent::AtomicFixnum.new(0) }
        end

        def init_last_synchronization
          @last_synchronization = Concurrent::Array.new

          @last_synchronization << { type: Domain::Constants::SPLIT_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::SEGMENT_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::EVENT_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::IMPRESSION_COUNT_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::IMPRESSIONS_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::TELEMETRY_SYNC, value: Concurrent::AtomicFixnum.new(0) }
          @last_synchronization << { type: Domain::Constants::TOKEN_SYNC, value: Concurrent::AtomicFixnum.new(0) }
        end

        def init_tags
          @tags = Concurrent::Array.new
        end

        def init_http_errors
          @http_errors = Concurrent::Array.new

          @http_errors << { type: Domain::Constants::SPLIT_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::SEGMENT_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::EVENT_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::IMPRESSION_COUNT_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::IMPRESSIONS_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::TELEMETRY_SYNC, value: Concurrent::Hash.new }
          @http_errors << { type: Domain::Constants::TOKEN_SYNC, value: Concurrent::Hash.new }
        end

        def init_http_latencies
          @http_latencies = Concurrent::Array.new

          array_size = BinarySearchLatencyTracker::BUCKETS.length
          @http_latencies << { type: Domain::Constants::SPLIT_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::SEGMENT_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::EVENT_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::IMPRESSION_COUNT_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::IMPRESSIONS_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::TELEMETRY_SYNC, value: Concurrent::Array.new(array_size, 0) }
          @http_latencies << { type: Domain::Constants::TOKEN_SYNC, value: Concurrent::Array.new(array_size, 0) }
        end

        def init_auth_rejections
          @auth_rejections = Concurrent::AtomicFixnum.new(0)
        end

        def init_token_refreshes
          @token_refreshes = Concurrent::AtomicFixnum.new(0)
        end

        def init_streaming_events
          @streaming_events = Concurrent::Array.new
        end

        def init_session_length
          @session_length = Concurrent::AtomicFixnum.new(0)
        end

        def init_updates_from_sse
          @updates_from_sse = Concurrent::Hash.new

          @updates_from_sse[Domain::Constants::SPLITS] = 0
        end
      end
    end
  end
end
