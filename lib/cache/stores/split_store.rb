module SplitIoClient
  module Cache
    module Stores
      class SplitStore
        attr_reader :split_cache

        def initialize(adapter, config, api_key, metrics)
          @split_cache = SplitIoClient::Cache::Split.new(adapter)
          @config = config
          @api_key = api_key
          @metrics = metrics
        end

        def call
          Thread.new do
            loop do
              store_splits

              sleep(random_interval)
            end
          end
        end

        private

        def store_splits
          data = splits_since(@split_cache.since)

          data[:splits] && data[:splits].each do |split|
            @split_cache.add_and_refresh(SplitIoClient::Split.new(split).to_h)
          end

          @split_cache.since = data[:till]
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def random_interval
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end

        def splits_since(since)
          SplitIoClient::Api::Splits.new(@api_key, @config, @metrics).since(since)
        end
      end
    end
  end
end
