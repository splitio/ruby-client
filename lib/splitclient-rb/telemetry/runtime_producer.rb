# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RuntimeProducer
      extend Forwardable
      def_delegators :@runtime,
                     :add_tag,
                     :record_impressions_stats,
                     :record_events_stats,
                     :record_successful_sync,
                     :record_sync_error,
                     :record_sync_latency,
                     :record_auth_rejections,
                     :record_token_refreshes,
                     :record_streaming_event,
                     :record_session_length

      def initialize(config, storage)
        @runtime = SplitIoClient::Telemetry::MemoryRuntimeProducer.new(config, storage)
      end
    end
  end
end
