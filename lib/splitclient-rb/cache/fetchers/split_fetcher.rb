module SplitIoClient
  module Cache
    module Fetchers
      class SplitFetcher
        attr_reader :splits_repository

        def initialize(splits_repository, api_key, metrics, config, sdk_blocker = nil)
          @splits_repository = splits_repository
          @api_key = api_key
          @metrics = metrics
          @config = config
          @sdk_blocker = sdk_blocker
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            fetch_splits
          else
            splits_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                splits_thread if forked
              end
            end
          end
        end

        def fetch_splits
          data = splits_since(@splits_repository.get_change_number)

          data[:splits] && data[:splits].each do |split|
            add_split_unless_archived(split)
          end

          @splits_repository.set_segment_names(data[:segment_names])
          @splits_repository.set_change_number(data[:till])

          @config.logger.debug("segments seen(#{data[:segment_names].length}): #{data[:segment_names].to_a}") if @config.debug_enabled

          @sdk_blocker.splits_ready!

        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def stop_splits_thread
          Thread.kill(@config.threads[:events_sender])
        rescue StandardError => error
          @config.logger.error(error.inspect)
        end

        private

        def splits_thread
          @config.threads[:split_fetcher] = Thread.new do
            @config.logger.info('Starting splits fetcher service')
            loop do
              fetch_splits

              sleep(StoreUtils.random_interval(@config.features_refresh_rate))
            end
          end
        end

        def splits_since(since)
          splits_api.since(since)
        end

        def add_split_unless_archived(split)
          if Engine::Models::Split.archived?(split)
            @config.logger.debug("Seeing archived split #{split[:name]}") if @config.debug_enabled

            remove_archived_split(split)
          else
            store_split(split)
          end
        end

        def remove_archived_split(split)
          @config.logger.debug("removing split from store(#{split})") if @config.debug_enabled

          @splits_repository.remove_split(split)
        end

        def store_split(split)
          @config.logger.debug("storing split (#{split[:name]})") if @config.debug_enabled

          @splits_repository.add_split(split)
        end

        def splits_api
          @splits_api ||= SplitIoClient::Api::Splits.new(@api_key, @metrics, @config)
        end
      end
    end
  end
end
