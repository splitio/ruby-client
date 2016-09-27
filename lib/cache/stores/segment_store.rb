module SplitIoClient
  module Cache
    module Stores
      class SegmentStore
        attr_reader :segments_repository

        def initialize(segments_repository, config, api_key, metrics)
          @segments_repository = segments_repository
          @config = config
          @api_key = api_key
          @metrics = metrics
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            store_segments
          else
            Thread.new do
              loop do
                store_segments

                sleep(random_interval(@config.segments_refresh_rate))
              end
            end
          end
        end

        private

        def store_segments
          segments_api.store_segments_by_names(@segments_repository.used_segment_names)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def random_interval(interval)
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end

        def segments_api
          SplitIoClient::Api::Segments.new(@api_key, @config, @metrics, @segments_repository)
        end
      end
    end
  end
end
