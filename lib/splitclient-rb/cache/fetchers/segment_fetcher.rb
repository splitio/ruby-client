module SplitIoClient
  module Cache
    module Fetchers
      class SegmentFetcher
        attr_reader :segments_repository

        def initialize(segments_repository, api_key, metrics, config, sdk_blocker = nil)
          @segments_repository = segments_repository
          @api_key = api_key
          @metrics = metrics
          @config = config
          @sdk_blocker = sdk_blocker
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            fetch_segments
          else
            segments_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                segments_thread if forked
              end
            end
          end
        end

        def fetch_segments
          segments_api.fetch_segments_by_names(@segments_repository.used_segment_names)

          @sdk_blocker.segments_ready!
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        private

        def segments_thread
          @config.threads[:segment_fetcher] = Thread.new do
            @config.logger.info('Starting segments fetcher service')

            loop do
              next unless @sdk_blocker.splits_repository.ready?

              fetch_segments
              @config.logger.debug("Segment names: #{@segments_repository.used_segment_names.to_a}") if @config.debug_enabled

              sleep_for = StoreUtils.random_interval(@config.segments_refresh_rate)
              @config.logger.debug("Segments store is sleeping for: #{sleep_for} seconds") if @config.debug_enabled
              sleep(sleep_for)
            end
          end
        end        

        def segments_api
          @segments_api ||= SplitIoClient::Api::Segments.new(@api_key, @metrics, @segments_repository, @config)
        end
      end
    end
  end
end
