# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Impressions
      class UniqueKeysTracker
        INTERVAL_TO_CLEAR_LONG_TERM_CACHE = 86_400 # 24 hours

        def initialize(config,
                       filter_adapter,
                       sender_adapter,
                       cache)
          @config = config
          @filter_adapter = filter_adapter
          @sender_adapter = sender_adapter
          @cache = cache
          @max_bulk_size = config.unique_keys_bulk_size
          @semaphore = Mutex.new
          @keys_size = 0
        end

        def call
          @config.threads[:unique_keys_sender] = Thread.new { send_bulk_data_thread }
          @config.threads[:clear_filter] = Thread.new { clear_filter_thread }
        end

        def track(feature_name, key)
          return false if @filter_adapter.contains?(feature_name, key)

          @filter_adapter.add(feature_name, key)

          add_or_update(feature_name, key)
          @keys_size += 1

          send_bulk_data if @keys_size >= @max_bulk_size

          true
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
          false
        end

        private

        def send_bulk_data_thread
          @config.logger.info('Starting Unique Keys Tracker.') if @config.debug_enabled
          loop do
            sleep(@config.unique_keys_refresh_rate)
            send_bulk_data
          end
        rescue SplitIoClient::SDKShutdownException
          send_bulk_data
          @config.logger.info('Posting unique keys due to shutdown')
        end

        def clear_filter_thread
          loop do
            sleep(INTERVAL_TO_CLEAR_LONG_TERM_CACHE)
            @config.logger.debug('Starting task to clean the filter cache.') if @config.debug_enabled
            @filter_adapter.clear
          end
        rescue SplitIoClient::SDKShutdownException
          @filter_adapter.clear
        end

        def add_or_update(feature_name, key)
          if @cache[feature_name].nil?
            @cache[feature_name] = Set.new([key])
          else
            @cache[feature_name].add(key)
          end
        end

        def send_bulk_data
          @semaphore.synchronize do
            return if @cache.empty?

            uniques = @cache.clone
            keys_size = @keys_size
            @cache.clear
            @keys_size = 0

            if keys_size <= @max_bulk_size
              @sender_adapter.record_uniques_key(uniques)
              return
            end

            bulks = []
            uniques.each do |unique|
              bulks += check_keys_and_split_to_bulks(unique)
            end

            bulks.each do |b|
              @sender_adapter.record_uniques_key(b)
            end
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def check_keys_and_split_to_bulks(unique)
          unique_updated = []
          unique.each do |_, value|
            if value.size > @max_bulk_size
              sub_bulks = SplitIoClient::Utilities.split_bulk_to_send(value, value.size / @max_bulk_size)
              sub_bulks.each do |sub_bulk|
                unique_updated.add({ key: sub_bulk })
              end
              break

            end
            unique_updated.add({ key: value })
          end

          unique_updated
        end
      end
    end
  end
end
