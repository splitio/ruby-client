# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Stores
      class SegmentStore
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
          @config.threads[:segment_store] = Thread.new do
            @config.logger.info('Starting segments fetcher service')

            loop do
              next unless @sdk_blocker.splits_ready?

              store_segments
              @config.split_logger.log_if_debug("Segment names: #{@segments_repository.used_segment_names}")

              sleep_for = StoreUtils.random_interval(@config.segments_refresh_rate)
              @config.split_logger.log_if_debug("Segments store is sleeping for: #{sleep_for} seconds")
              sleep(sleep_for)
            end
          end
        end

        def store_segments
          segments_api.store_segments_by_names(@segments_repository.used_segment_names)

          @sdk_blocker.segments_ready!
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def segments_api
          @segments_api ||= SplitIoClient::Api::Segments.new(@api_key, @metrics, @segments_repository, @config)
        end
      end
    end
  end
end
