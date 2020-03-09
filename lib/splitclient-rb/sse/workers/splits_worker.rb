# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(split_fetch, config, splits_repository)
          @split_fetch = split_fetch
          @config = config
          @splits_repository = splits_repository
          @queue = Queue.new
        end

        def start
          perform_thread
          perform_passenger_forked if defined?(PhusionPassenger)
        end

        def add_to_queue(change_number)
          @queue.push(change_number)
        end

        def kill_split(change_number, split_name, default_treatment)
          @splits_repository.kill(change_number, split_name, default_treatment)
          add_to_queue(change_number)
        end

        private

        def perform
          while (change_number = @queue.pop)
            since = @splits_repository.get_change_number
            @split_fetch.fetch_splits unless since >= change_number
          end
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
  end
end
