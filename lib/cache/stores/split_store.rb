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
            @sdk_blocker.splits_thread = Thread.new do
              loop do
                store_splits

                sleep(random_interval(@config.features_refresh_rate))
              end
            end
          end
        end

        private

        def store_splits
          data = splits_since(@splits_repository.get_change_number)

          data[:splits] && data[:splits].each do |split|
            @splits_repository.add_split(split)
          end

          @splits_repository.set_segment_names(data[:segment_names])
          @splits_repository.set_change_number(data[:till])

          @config.logger.debug('Splits end reached') if @config.debug_enabled

          broadcast_ready!
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

        def broadcast_ready!
          return unless @config.block_until_ready

          unless @sdk_blocker.ready?
            @sdk_blocker.splits_ready!
            Thread.stop
          end
        end
      end
    end
  end
end
