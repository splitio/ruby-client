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
        fetchers
      )
        @splits_repository = repositories[:splits]
        @segments_repository = repositories[:segments]
        @impressions_repository = repositories[:impressions]
        @metrics_repository = repositories[:metrics]
        @events_repository = repositories[:events]
        @api_key = api_key
        @config = config
        @sdk_blocker = sdk_blocker
        @split_fetcher = fetchers[:split]
        @segment_fetcher = fetchers[:segment]
      end

      def sync_all
        fetch_splits
        fetch_segments
      end

      def start_periodic_data_recording
        @metrics_sender = metrics_sender
        @impressions_sender = impressions_sender
        @events_sender = events_sender
      end

      def start_periodic_fetch
        @split_fetcher.call
        @segment_fetcher.call
      end

      def stop_periodic_fetch
        @split_fetcher.stop_splits_thread
        @segment_fetcher.stop_segments_thread
      end

      private

      def fetch_splits
        @split_fetcher.fetch_splits
      end

      def fetch_segments
        @segment_fetcher.fetch_segments
      end

      # Starts thread which loops constantly and sends impressions to the Split API
      def impressions_sender
        ImpressionsSender.new(@impressions_repository, @api_key, @config).call
      end

      # Starts thread which loops constantly and sends metrics to the Split API
      def metrics_sender
        MetricsSender.new(@metrics_repository, @api_key, @config).call
      end

      # Starts thread which loops constantly and sends events to the Split API
      def events_sender
        EventsSender.new(@events_repository, @config).call
      end
    end
  end
end
