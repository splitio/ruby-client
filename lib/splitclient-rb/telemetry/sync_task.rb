# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class SyncTask
      def initialize(config, telemetry_synchronizer)
        @config = config
        @telemetry_synchronizer = telemetry_synchronizer
      end

      def call
        telemetry_thread

        PhusionPassenger.on_event(:starting_worker_process) { |forked| telemetry_thread if forked } if defined?(PhusionPassenger)
      end

      private

      def telemetry_thread
        @config.threads[:telemetry_sender] = Thread.new do
          begin
            @config.logger.info('Starting Telemetry Sync Task')

            loop do
              sleep(@config.telemetry_refresh_rate)

              @telemetry_synchronizer.synchronize_stats
            end
          rescue SplitIoClient::SDKShutdownException
            @telemetry_synchronizer.synchronize_stats

            @config.logger.info('Posting Telemetry due to shutdown')
          end
        end
      end
    end
  end
end
