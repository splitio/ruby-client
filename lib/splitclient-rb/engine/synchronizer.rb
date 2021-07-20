# frozen_string_literal: true

module SplitIoClient
  module Engine
    class Synchronizer
      include SplitIoClient::Cache::Fetchers
      include SplitIoClient::Cache::Senders

      ON_DEMAND_FETCH_BACKOFF_BASE_MS = 10_000
      ON_DEMAND_FETCH_BACKOFF_MAX_WAIT_MS = 60_000
      ON_DEMAND_FETCH_BACKOFF_MAX_RETRIES = 10

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
        @backoff = new SSE::EventSource::BackOff.new()
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

      def fetch_splits(target_change_number)
        return if target_change_number <= @splits_repository.get_change_number

        fetch_options = { cache_control_headers: true, till: nil }

        result = attempt_splits_sync(target_change_number,
                                     fetch_options,
                                     @config.on_demand_fetch_max_retries,
                                     @config.on_demand_fetch_retry_delay_ms)

        attempts = @config.on_demand_fetch_max_retries - result[:remaining_attempts]
        if result[:success]
          @segment_fetcher.fetch_segments_if_not_exists(result[:segment_names], true) unless result[:segment_names].empty?
          @config.logger.debug("Refresh completed in #{attempts} attempts.") if @config.debug_enabled

          return
        end

        fetch_options[:till] = target_change_number
        result = attempt_splits_sync(target_change_number,
                                     fetch_options,
                                     ON_DEMAND_FETCH_BACKOFF_MAX_RETRIES,
                                     @config.on_demand_fetch_retry_delay_ms)

        attempts = @config.on_demand_fetch_max_retries - result[:remaining_attempts]

        if result[:success]
          @segment_fetcher.fetch_segments_if_not_exists(result[:segment_names], true) unless result[:segment_names].empty?
          @config.logger.debug("Refresh completed bypassing the CDN in #{attempts} attempts.")
        else
          @config.logger.debug("No changes fetched after #{attempts} attempts with CDN bypassed.")
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def fetch_segment(name)
        fetch_options = { cache_control_headers: true, till: nil }
        @segment_fetcher.fetch_segment(name, fetch_options)
      end

      private

      def attempt_splits_sync(target_cn, fetch_options, max_retries, retry_delay_ms)
        remaining_attempts = max_retries

        loop do
          remaining_attempts -= 1

          segment_names = @split_fetcher.fetch_splits(fetch_options)

          return split_sync_result(true, remaining_attempts, segment_names) if target_cn <= @splits_repository.get_change_number
          return split_sync_result(false, remaining_attempts, segment_names) if remaining_attempts <= 0

          sleep(retry_delay_ms)
        end
      end

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

      def split_sync_result(success, remaining_attempts, segment_names)
        { success: success, remaining_attempts: remaining_attempts, segment_names: segment_names }
      end
    end
  end
end
