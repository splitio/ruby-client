module SplitIoClient
  module Cache
    module Stores
      class SplitStore
        attr_reader :splits_repository

        def initialize(splits_repository, config, api_key, metrics, sdk_blocker = nil)
          @splits_repository = splits_repository
          @config = config
          @api_key = api_key
          @metrics = metrics
          @sdk_blocker = sdk_blocker
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            store_splits
          else
            splits_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                splits_thread if forked
              end
            end
          end
        end

        private

        def splits_thread
          @sdk_blocker.splits_thread = Thread.new do
            @config.logger.info('Starting splits fetcher service')
            loop do
              store_splits

              sleep(random_interval(@config.features_refresh_rate))
            end
          end
        end

        def store_splits
          data = splits_since(@splits_repository.get_change_number)

          data[:splits] && data[:splits].each do |split|
            add_split_unless_archived(split)
          end

          @splits_repository.set_segment_names(data[:segment_names])
          @splits_repository.set_change_number(data[:till])

          @config.logger.debug("segments seen(#{data[:segment_names].length}): #{data[:segment_names].to_a}") if @config.debug_enabled

          if @config.block_until_ready > 0 && !@sdk_blocker.ready?
            @sdk_blocker.splits_ready!
            @config.logger.info('splits are ready')
          end

        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def random_interval(interval)
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end

        def splits_since(since)
          SplitIoClient::Api::Splits.new(@api_key, @config, @metrics).since(since)
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

          @splits_repository.remove_split(split[:name])
        end

        def store_split(split)
          @config.logger.debug("storing split (#{split[:name]})") if @config.debug_enabled

          @splits_repository.add_split(split)
        end
      end
    end
  end
end
