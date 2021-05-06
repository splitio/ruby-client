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
                    :last_synchronization_records,
                    :http_errors,
                    :http_latencies,
                    :auth_rejections,
                    :token_refreshes,
                    :streaming_events,
                    :session_length

        def initialize
          @latencies = Concurrent::Array.new
          @exceptions = Concurrent::Array.new
          @factory_counters = Concurrent::Array.new
          @tags = Concurrent::Array.new
          @impressions_data_records = Concurrent::Array.new
          @events_data_records = Concurrent::Array.new
          @last_synchronization_records = Concurrent::Array.new
          @http_errors = Concurrent::Array.new
          @http_latencies = Concurrent::Array.new
          @auth_rejections = Concurrent::AtomicFixnum.new(0)
          @token_refreshes = Concurrent::AtomicFixnum.new(0)
          @streaming_events = Concurrent::Array.new
          @session_length = Concurrent::AtomicFixnum.new(0)
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

        def clear_http_errors
          @http_errors = Concurrent::Array.new
        end

        def clear_http_latencies
          @http_latencies = Concurrent::Array.new
        end

        def clear_auth_rejections
          @auth_rejections = Concurrent::AtomicFixnum.new(0)
        end

        def clear_token_refreshes
          @token_refreshes = Concurrent::AtomicFixnum.new(0)
        end

        def clear_streaming_events
          @streaming_events = Concurrent::Array.new
        end
      end
    end
  end
end
