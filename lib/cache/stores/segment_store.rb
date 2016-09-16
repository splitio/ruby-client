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
          data = segments_by_names(@segments_repository.used_segment_names)

          data && data.each do |segment|
            @segments_repository.add(segment)
          end
        end

        def random_interval(interval)
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end

        def segments_api
          SplitIoClient::Api::Segments.new(@api_key, @config, @metrics, @segments_repository)
        end

        def segments_by_names(names)
          segments_api.by_names(names)
        end
      end
    end
  end
end
