module SplitIoClient
  module Cache
    module Stores
      class SegmentStore
        attr_reader :segment_cache

        def initialize(segment_cache, splits_cache, config, api_key, metrics)
          @segment_cache = segment_cache
          @splits_cache = splits_cache
          @config = config
          @api_key = api_key
          @metrics = metrics
        end

        def call
          Thread.new do
            begin
              loop do
                store_segments

                sleep(random_interval(@config.segments_refresh_rate))
              end
            rescue StandardError => error
              @config.log_found_exception(__method__.to_s, error)
            end
          end
        end

        private

        def store_segments
          data = segments_by_names(@splits_cache.used_segments_names)

          data && data.each do |segment|
            @segment_cache.add(segment)
          end
        end

        def random_interval(interval)
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end

        def segments_api
          SplitIoClient::Api::Segments.new(@api_key, @config, @metrics, @segment_cache)
        end

        def segments_by_names(names)
          segments_api.by_names(names)
        end
      end
    end
  end
end
