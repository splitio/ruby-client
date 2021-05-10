# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class InitConsumer
      extend Forwardable
      def_delegators :@init, :non_ready_usages, :bur_timeouts

      def initialize(config, storage)
        @init = SplitIoClient::Telemetry::MemoryInitConsumer.new(config, storage)
      end
    end
  end
end
