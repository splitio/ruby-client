# frozen_string_literal: true

module SplitIoClient
  class SegmentUpdateWorker
    def initialize(adapter, config, segments_repository)
      @adapter = adapter
      @config = config
      @segments_repository = segments_repository
      @queue = Queue.new

      perform_thread

      perform_passenger_forked if defined?(PhusionPassenger)
    end

    def add_to_adapter(change_number, segment_name)
      segment_notification = { change_number: change_number, segment_name: segment_name }
      @queue.push(segment_notification)
    end

    private

    def perform
      while (segment_updated = @queue.pop)
        segment_name = segment_updated['segment_name']
        change_number = segment_updated['change_number']
        since = @segments_repository.get_change_number(segment_name)

        @adapter.segment_fetcher.fetch_segment(segment_name) unless since >= change_number
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
