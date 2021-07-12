# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class InitConsumer
      extend Forwardable
      def_delegators :@init, :non_ready_usages, :bur_timeouts

      def initialize(config)
        @init = SplitIoClient::Telemetry::MemoryInitConsumer.new(config)
      end
    end
  end
end
