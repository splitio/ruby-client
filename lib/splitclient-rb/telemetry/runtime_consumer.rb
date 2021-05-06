# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RuntimeConsumer
      extend Forwardable
      def_delegators :@runtime,
                     :pop_tags,
                     :impressions_stats,
                     :events_stats,
                     :last_synchronizations,
                     :pop_http_errors,
                     :pop_http_latencies,
                     :pop_auth_rejections,
                     :pop_token_refreshes,
                     :pop_streaming_events,
                     :session_length

      def initialize(config, storage)
        @runtime = SplitIoClient::Telemetry::MemoryRuntimeConsumer.new(config, storage)
      end
    end
  end
end
