module SplitIoClient
  module Cache
    module Fetchers
      class SegmentFetcher
        attr_reader :segments_repository

        def initialize(segments_repository, api_key, config, sdk_blocker = nil)
          @segments_repository = segments_repository
          @api_key = api_key
          @config = config
          @sdk_blocker = sdk_blocker
          @semaphore = Mutex.new
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

        def fetch_segments_if_not_exists(names)
          names.each do |name|
            change_number = @segments_repository.get_change_number(name)

            fetch_segment(name) if change_number == -1
          end
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def fetch_segment(name)
          @semaphore.synchronize do
            segments_api.fetch_segments_by_names([name])
          end
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def fetch_segments
          @semaphore.synchronize do
            segments_api.fetch_segments_by_names(@segments_repository.used_segment_names)

            @sdk_blocker.segments_ready!
          end
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def stop_segments_thread
          SplitIoClient::Helpers::ThreadHelper.stop(:segment_fetcher, @config)
        end

        private

        def segments_thread
          @config.threads[:segment_fetcher] = Thread.new do
            @config.logger.info('Starting segments fetcher service') if @config.debug_enabled

            loop do
              next unless @sdk_blocker.splits_repository.ready?

              fetch_segments
              @config.logger.debug("Segment names: #{@segments_repository.used_segment_names.to_a}") if @config.debug_enabled

              sleep_for = SplitIoClient::Cache::Stores::StoreUtils.random_interval(@config.segments_refresh_rate)
              @config.logger.debug("Segments fetcher is sleeping for: #{sleep_for} seconds") if @config.debug_enabled
              sleep(sleep_for)
            end
          end
        end        

        def segments_api
          @segments_api ||= SplitIoClient::Api::Segments.new(@api_key, @segments_repository, @config)
        end
      end
    end
  end
end
