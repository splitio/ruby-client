# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class SyncTask
      def initialize(config, telemetry_synchronizer)
        @config = config
        @telemetry_synchronizer = telemetry_synchronizer
      end

      def call
        stats_thread
      end

      private

      def stats_thread
        @config.threads[:telemetry_stats_sender] = Thread.new { telemetry_sync_task }
      end

      def telemetry_sync_task
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
