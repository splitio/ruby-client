# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(synchronizer, config, splits_repository)
          @synchronizer = synchronizer
          @config = config
          @splits_repository = splits_repository
        end

        def start
          @queue = Queue.new
          perform_thread
          perform_passenger_forked if defined?(PhusionPassenger)
        end

        def add_to_queue(change_number)
          return if @queue.nil?

          @config.logger.debug("SplitsWorker add to queue #{change_number}")
          @queue.push(change_number)
        end

        def kill_split(change_number, split_name, default_treatment)
          return if @queue.nil?

          @config.logger.debug("SplitsWorker kill #{split_name}, #{change_number}")
          @splits_repository.kill(change_number, split_name, default_treatment)
          add_to_queue(change_number)
        end

        def stop
          SplitIoClient::Helpers::ThreadHelper.stop(:split_update_worker, @config)
          @queue = nil
        end

        private

        def perform
          while (change_number = @queue.pop)
            since = @splits_repository.get_change_number

            unless since.to_i >= change_number
              @config.logger.debug("SplitsWorker fetch_splits with #{since}")
              @synchronizer.fetch_splits
            end
          end
        end

        def perform_thread
          @config.threads[:split_update_worker] = Thread.new do
            @config.logger.debug('Starting splits worker ...') if @config.debug_enabled
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
