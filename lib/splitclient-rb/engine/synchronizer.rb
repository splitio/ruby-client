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
        @metrics_repository = repositories[:metrics]
        @events_repository = repositories[:events]
        @api_key = api_key
        @config = config
        @sdk_blocker = sdk_blocker
        @split_fetcher = params[:split_fetcher]
        @segment_fetcher = params[:segment_fetcher]
        @impressions_api = SplitIoClient::Api::Impressions.new(@api_key, @config)
        @impression_counter = params[:imp_counter]
      end

      def sync_all
        @config.logger.debug('Synchronizing Splits and Segments ...') if @config.debug_enabled
        fetch_splits
        fetch_segments
      end

      def start_periodic_data_recording
        impressions_sender
        metrics_sender
        events_sender
        impressions_count_sender
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
        back_off = SplitIoClient::SSE::EventSource::BackOff.new(SplitIoClient::Constants::FETCH_BACK_OFF_BASE_RETRIES, 1)
        loop do
          break if @split_fetcher.fetch_splits

          sleep(back_off.interval)
        end
      end

      def fetch_segment(name)
        back_off = SplitIoClient::SSE::EventSource::BackOff.new(SplitIoClient::Constants::FETCH_BACK_OFF_BASE_RETRIES, 1)
        loop do
          break if @segment_fetcher.fetch_segment(name)

          sleep(back_off.interval)
        end
      end

      private

      def fetch_segments
        @segment_fetcher.fetch_segments
      end

      # Starts thread which loops constantly and sends impressions to the Split API
      def impressions_sender
        ImpressionsSender.new(@impressions_repository, @config, @impressions_api).call
      end

      # Starts thread which loops constantly and sends metrics to the Split API
      def metrics_sender
        MetricsSender.new(@metrics_repository, @api_key, @config).call
      end

      # Starts thread which loops constantly and sends events to the Split API
      def events_sender
        EventsSender.new(@events_repository, @config).call
      end

      # Starts thread which loops constantly and sends impressions count to the Split API
      def impressions_count_sender
        ImpressionsCountSender.new(@config, @impression_counter, @impressions_api).call
      end
    end
  end
end
