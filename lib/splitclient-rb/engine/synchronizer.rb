# frozen_string_literal: true

module SplitIoClient
  module Engine
    class Synchronizer
      include SplitIoClient::Cache::Fetchers
      include SplitIoClient::Cache::Senders

      def initialize(
        repositories,
        api_key,
        config,
        sdk_blocker,
        params
      )
        @splits_repository = repositories[:splits]
        @segments_repository = repositories[:segments]
        @impressions_repository = repositories[:impressions]
        @events_repository = repositories[:events]
        @api_key = api_key
        @config = config
        @sdk_blocker = sdk_blocker
        @split_fetcher = params[:split_fetcher]
        @segment_fetcher = params[:segment_fetcher]
        @impressions_api = SplitIoClient::Api::Impressions.new(@api_key, @config, params[:telemetry_runtime_producer])
        @impression_counter = params[:imp_counter]
        @telemetry_synchronizer = params[:telemetry_synchronizer]
      end

      def sync_all
        @config.threads[:sync_all_thread] = Thread.new do
          @config.logger.debug('Synchronizing Splits and Segments ...') if @config.debug_enabled
          @split_fetcher.fetch_splits
          @segment_fetcher.fetch_segments
        end
      end

      def start_periodic_data_recording
        impressions_sender
        events_sender
        impressions_count_sender
        start_telemetry_sync_task
      end

      def start_periodic_fetch
        @split_fetcher.call
        @segment_fetcher.call
      end

      def stop_periodic_fetch
        @split_fetcher.stop_splits_thread
        @segment_fetcher.stop_segments_thread
      end

      def fetch_splits
        segment_names = @split_fetcher.fetch_splits
        @segment_fetcher.fetch_segments_if_not_exists(segment_names) unless segment_names.empty?
      end

      def fetch_segment(name)
        @segment_fetcher.fetch_segment(name)
      end

      private

      def fetch_segments
        @segment_fetcher.fetch_segments
      end

      # Starts thread which loops constantly and sends impressions to the Split API
      def impressions_sender
        ImpressionsSender.new(@impressions_repository, @config, @impressions_api).call
      end

      # Starts thread which loops constantly and sends events to the Split API
      def events_sender
        EventsSender.new(@events_repository, @config).call
      end

      # Starts thread which loops constantly and sends impressions count to the Split API
      def impressions_count_sender
        ImpressionsCountSender.new(@config, @impression_counter, @impressions_api).call
      end

      def start_telemetry_sync_task
        Telemetry::SyncTask.new(@config, @telemetry_synchronizer).call
      end
    end
  end
end
