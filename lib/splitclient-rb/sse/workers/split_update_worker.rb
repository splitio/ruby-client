# frozen_string_literal: true

module SplitIoClient
  class SplitUpdateWorker
    def initialize(adapter, config, splits_repository)
      @adapter = adapter
      @config = config
      @splits_repository = splits_repository
      @queue = Queue.new

      perform_thread

      perform_passenger_forked if defined?(PhusionPassenger)
    end

    def add_to_adapter(change_number)
      @queue.push(change_number)
    end

    private

    def perform
      p '1-perform'
      while (change_number = @queue.pop)
        p '2-perform'
        current_change_number = @splits_repository.get_change_number
        p current_change_number
        p change_number
        @adapter.split_fetcher.fetch_splits unless current_change_number >= change_number
      end
      p '3-perform'
    end

    def perform_thread
      @config.threads[:split_update_worker] = Thread.new do
        perform
      end
    end

    def perform_passenger_forked
      PhusionPassenger.on_event(:starting_worker_process) { |forked| perform_thread if forked }
    end
  end
end
