# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class InitProducer
      extend Forwardable
      def_delegators :@init, :record_config, :record_non_ready_usages, :record_bur_timeout

      def initialize(config, storage)
        @init = SplitIoClient::Telemetry::MemoryInitProducer.new(config, storage)
      end
    end
  end
end
