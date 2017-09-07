module SplitIoClient
  module Cache
    module Stores
      class SegmentStore
        attr_reader :segments_repository

        def initialize(segments_repository, config, api_key, metrics, sdk_blocker = nil)
          @segments_repository = segments_repository
          @config = config
          @api_key = api_key
          @metrics = metrics
          @sdk_blocker = sdk_blocker
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            store_segments
          else
            segments_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                segments_thread if forked
              end
            end
          end
        end

        private

        def segments_thread
          @config.threads[:segment_store] = @sdk_blocker.segments_thread = Thread.new do
            @config.logger.info('Starting segments fetcher service')
            @config.block_until_ready > 0 ? blocked_store : unblocked_store
          end
        end

        def blocked_store
          loop do
            next unless @sdk_blocker.splits_repository.ready?

            store_segments
            @config.logger.debug("Segment names: #{@segments_repository.used_segment_names.to_a}") if @config.debug_enabled

            unless @sdk_blocker.ready?
              @sdk_blocker.segments_ready!
              @config.logger.info('segments are ready')
            end

            sleep_for = random_interval(@config.segments_refresh_rate)
            @config.logger.debug("Segments store is sleeping for: #{sleep_for} seconds") if @config.debug_enabled
            sleep(sleep_for)
          end
        end

        def unblocked_store
          loop do
            store_segments

            sleep(random_interval(@config.segments_refresh_rate))
          end
        end

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
