module SplitIoClient
  module Cache
    module Fetchers
      class SegmentFetcher
        attr_reader :segments_repository

        def initialize(segments_repository, api_key, config, telemetry_runtime_producer, request_decorator)
          @segments_repository = segments_repository
          @api_key = api_key
          @config = config
          @semaphore = Mutex.new
          @telemetry_runtime_producer = telemetry_runtime_producer
          @request_decorator = request_decorator
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            fetch_segments
            return
          end

          segments_thread
        end

        def fetch_segments_if_not_exists(names, cache_control_headers = false)
          names.each do |name|
            change_number = @segments_repository.get_change_number(name)

            if change_number == -1
              fetch_options = { cache_control_headers: cache_control_headers, till: nil }
              fetch_segment(name, fetch_options) if change_number == -1
            end
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def fetch_segment(name, fetch_options = { cache_control_headers: false, till: nil })
          @semaphore.synchronize do
            segments_api.fetch_segments_by_names([name], fetch_options)
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def fetch_segments
          @semaphore.synchronize do
            segments_api.fetch_segments_by_names(@segments_repository.used_segment_names)

            true
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
          false
        end

        def stop_segments_thread
          SplitIoClient::Helpers::ThreadHelper.stop(:segment_fetcher, @config)
        end

        private

        def segments_thread
          @config.threads[:segment_fetcher] = Thread.new do
            @config.logger.info('Starting segments fetcher service') if @config.debug_enabled

            loop do
              fetch_segments
              @config.logger.debug("Segment names: #{@segments_repository.used_segment_names.to_a}") if @config.debug_enabled

              sleep_for = SplitIoClient::Cache::Stores::StoreUtils.random_interval(@config.segments_refresh_rate)
              @config.logger.debug("Segments fetcher is sleeping for: #{sleep_for} seconds") if @config.debug_enabled
              sleep(sleep_for)
            end
          end
        end

        def segments_api
          @segments_api ||= SplitIoClient::Api::Segments.new(@api_key, @segments_repository, @config, @telemetry_runtime_producer, @request_decorator)
        end
      end
    end
  end
end
