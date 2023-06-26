module SplitIoClient
  module Cache
    module Fetchers
      class SplitFetcher
        attr_reader :splits_repository

        def initialize(splits_repository, api_key, config, telemetry_runtime_producer)
          @splits_repository = splits_repository
          @api_key = api_key
          @config = config
          @semaphore = Mutex.new
          @telemetry_runtime_producer = telemetry_runtime_producer
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            fetch_splits
            return
          end
          
          splits_thread
        end

        def fetch_splits(fetch_options = { cache_control_headers: false, till: nil })
          @semaphore.synchronize do
            data = splits_since(@splits_repository.get_change_number, fetch_options)

            data[:splits] && data[:splits].each do |split|
              add_split_unless_archived(split)
            end

            @splits_repository.set_segment_names(data[:segment_names])
            @splits_repository.set_change_number(data[:till])

            @config.logger.debug("segments seen(#{data[:segment_names].length}): #{data[:segment_names].to_a}") if @config.debug_enabled

            { segment_names: data[:segment_names], success: true }
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
          { segment_names: [], success: false }
        end

        def stop_splits_thread
          SplitIoClient::Helpers::ThreadHelper.stop(:split_fetcher, @config)
        end

        private

        def splits_thread
          @config.threads[:split_fetcher] = Thread.new do
            @config.logger.info('Starting feature flags fetcher service') if @config.debug_enabled
            loop do
              fetch_splits

              sleep_for = SplitIoClient::Cache::Stores::StoreUtils.random_interval(@config.features_refresh_rate)
              @config.logger.debug("Feature flags fetcher is sleeping for: #{sleep_for} seconds") if @config.debug_enabled
              sleep(sleep_for)
            end
          end
        end

        def splits_since(since, fetch_options = { cache_control_headers: false, till: nil })
          splits_api.since(since, fetch_options)
        end

        def add_split_unless_archived(split)
          if Engine::Models::Split.archived?(split)
            @config.logger.debug("Seeing archived feature flag #{split[:name]}") if @config.debug_enabled

            remove_archived_split(split)
          else
            store_split(split)
          end
        end

        def remove_archived_split(split)
          @config.logger.debug("removing feature flag from store(#{split})") if @config.debug_enabled

          @splits_repository.remove_split(split)
        end

        def store_split(split)
          @config.logger.debug("storing feature flag (#{split[:name]})") if @config.debug_enabled

          @splits_repository.add_split(split)
        end

        def splits_api
          @splits_api ||= SplitIoClient::Api::Splits.new(@api_key, @config, @telemetry_runtime_producer)
        end
      end
    end
  end
end
