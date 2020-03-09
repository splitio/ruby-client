# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SegmentsWorker
        def initialize(segment_fetcher, config, segments_repository)
          @segment_fetcher = segment_fetcher
          @config = config
          @segments_repository = segments_repository
          @queue = Queue.new
        end

        def start
          perform_thread
          perform_passenger_forked if defined?(PhusionPassenger)
        end

        def add_to_queue(change_number, segment_name)
          item = { change_number: change_number, segment_name: segment_name }
          @queue.push(item)
        end

        private

        def perform
          while (item = @queue.pop)
            segment_name = item[:segment_name]
            change_number = item[:change_number]
            since = @segments_repository.get_change_number(segment_name)

            @segment_fetcher.fetch_segment(segment_name) unless since >= change_number
          end
        end

        def perform_thread
          @config.threads[:segment_update_worker] = Thread.new do
            perform
          end
        end

        def perform_passenger_forked
          PhusionPassenger.on_event(:starting_worker_process) { |forked| perform_thread if forked }
        end
      end
    end
  end
end
