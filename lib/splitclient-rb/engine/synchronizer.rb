# frozen_string_literal: true

module SplitIoClient
  module Engine
    class Synchronizer
      include SplitIoClient::Cache::Fetchers
      include SplitIoClient::Cache::Senders

      ON_DEMAND_FETCH_BACKOFF_BASE_SECONDS = 10
      ON_DEMAND_FETCH_BACKOFF_MAX_WAIT_SECONDS = 60
      ON_DEMAND_FETCH_BACKOFF_MAX_RETRIES = 10

      def initialize(
        repositories,
        config,
        params
      )
        @splits_repository = repositories[:splits]
        @segments_repository = repositories[:segments]
        @impressions_repository = repositories[:impressions]
        @events_repository = repositories[:events]
        @config = config
        @split_fetcher = params[:split_fetcher]
        @segment_fetcher = params[:segment_fetcher]
        @impressions_api = params[:impressions_api]
        @impression_counter = params[:imp_counter]
        @telemetry_synchronizer = params[:telemetry_synchronizer]
        @impressions_sender_adapter = params[:impressions_sender_adapter]
        @unique_keys_tracker = params[:unique_keys_tracker]
      end

      def sync_all(asynchronous = true)
        unless asynchronous
          return sync_splits_and_segments
        end

        @config.threads[:sync_all_thread] = Thread.new do
          sync_splits_and_segments
        end

        true
      end

      def start_periodic_data_recording
        impressions_sender
        impressions_count_sender
        events_sender
        start_telemetry_sync_task
        start_unique_keys_tracker_task
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
        return if target_change_number <= @splits_repository.get_change_number.to_i

        fetch_options = { cache_control_headers: true, till: nil }

        result = attempt_splits_sync(target_change_number,
                                     fetch_options,
                                     @config.on_demand_fetch_max_retries,
                                     @config.on_demand_fetch_retry_delay_seconds,
                                     false)

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
                                     nil,
                                     true)

        attempts = ON_DEMAND_FETCH_BACKOFF_MAX_RETRIES - result[:remaining_attempts]

        if result[:success]
          @segment_fetcher.fetch_segments_if_not_exists(result[:segment_names], true) unless result[:segment_names].empty?
          @config.logger.debug("Refresh completed bypassing the CDN in #{attempts} attempts.") if @config.debug_enabled
        else
          @config.logger.debug("No changes fetched after #{attempts} attempts with CDN bypassed.") if @config.debug_enabled
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def fetch_segment(name, target_change_number)
        return if target_change_number <= @segments_repository.get_change_number(name).to_i

        fetch_options = { cache_control_headers: true, till: nil }
        result = attempt_segment_sync(name,
                                      target_change_number,
                                      fetch_options,
                                      @config.on_demand_fetch_max_retries,
                                      @config.on_demand_fetch_retry_delay_seconds,
                                      false)

        attempts = @config.on_demand_fetch_max_retries - result[:remaining_attempts]
        if result[:success]
          @config.logger.debug("Segment #{name} refresh completed in #{attempts} attempts.") if @config.debug_enabled

          return
        end

        fetch_options = { cache_control_headers: true, till: target_change_number }
        result = attempt_segment_sync(name,
                                      target_change_number,
                                      fetch_options,
                                      ON_DEMAND_FETCH_BACKOFF_MAX_RETRIES,
                                      nil,
                                      true)

        attempts = @config.on_demand_fetch_max_retries - result[:remaining_attempts]
        if result[:success]
          @config.logger.debug("Segment #{name} refresh completed bypassing the CDN in #{attempts} attempts.") if @config.debug_enabled
        else
          @config.logger.debug("No changes fetched for segment #{name} after #{attempts} attempts with CDN bypassed.") if @config.debug_enabled
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def attempt_segment_sync(name, target_cn, fetch_options, max_retries, retry_delay_seconds, with_backoff)
        remaining_attempts = max_retries
        backoff = Engine::BackOff.new(ON_DEMAND_FETCH_BACKOFF_BASE_SECONDS, 0, ON_DEMAND_FETCH_BACKOFF_MAX_WAIT_SECONDS) if with_backoff

        loop do
          remaining_attempts -= 1

          @segment_fetcher.fetch_segment(name, fetch_options)

          return sync_result(true, remaining_attempts) if target_cn <= @segments_repository.get_change_number(name).to_i
          return sync_result(false, remaining_attempts) if remaining_attempts <= 0

          delay = with_backoff ? backoff.interval : retry_delay_seconds
          sleep(delay)
        end
      end

      def attempt_splits_sync(target_cn, fetch_options, max_retries, retry_delay_seconds, with_backoff)
        remaining_attempts = max_retries
        backoff = Engine::BackOff.new(ON_DEMAND_FETCH_BACKOFF_BASE_SECONDS, 0, ON_DEMAND_FETCH_BACKOFF_MAX_WAIT_SECONDS) if with_backoff

        loop do
          remaining_attempts -= 1

          result = @split_fetcher.fetch_splits(fetch_options)

          return sync_result(true, remaining_attempts, result[:segment_names]) if target_cn <= @splits_repository.get_change_number
          return sync_result(false, remaining_attempts, result[:segment_names]) if remaining_attempts <= 0

          delay = with_backoff ? backoff.interval : retry_delay_seconds
          sleep(delay)
        end
      end

      # Starts thread which loops constantly and sends impressions to the Split API
      def impressions_sender
        ImpressionsSender.new(@impressions_repository, @config, @impressions_api).call unless @config.impressions_mode == :none
      end

      # Starts thread which loops constantly and sends events to the Split API
      def events_sender
        EventsSender.new(@events_repository, @config).call
      end

      # Starts thread which loops constantly and sends impressions count to the Split API
      def impressions_count_sender
        ImpressionsCountSender.new(@config, @impression_counter, @impressions_sender_adapter).call unless @config.impressions_mode == :debug
      end

      def start_telemetry_sync_task
        Telemetry::SyncTask.new(@config, @telemetry_synchronizer).call
      end

      def start_unique_keys_tracker_task
        @unique_keys_tracker.call
      end

      def sync_result(success, remaining_attempts, segment_names = nil)
        { success: success, remaining_attempts: remaining_attempts, segment_names: segment_names }
      end

      def sync_splits_and_segments
        @config.logger.debug('Synchronizing Splits and Segments ...') if @config.debug_enabled
        splits_result = @split_fetcher.fetch_splits
        
        splits_result[:success] && @segment_fetcher.fetch_segments
      end
    end
  end
end
