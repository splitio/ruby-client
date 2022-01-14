# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(synchronizer, config, splits_repository)
          @synchronizer = synchronizer
          @config = config
          @splits_repository = splits_repository
          @queue = Queue.new
          @running = Concurrent::AtomicBoolean.new(false)
        end

        def start
          if @running.value
            @config.logger.debug('splits worker already running.')
            return
          end

          @running.make_true
          perform_thread
        end

        def stop
          unless @running.value
            @config.logger.debug('splits worker not running.')
            return
          end

          @running.make_false
          SplitIoClient::Helpers::ThreadHelper.stop(:split_update_worker, @config)
        end

        def add_to_queue(change_number)
          unless @running.value
            @config.logger.debug('splits worker not running.')
            return
          end

          @config.logger.debug("SplitsWorker add to queue #{change_number}")
          @queue.push(change_number)
        end

        def kill_split(change_number, split_name, default_treatment)
          unless @running.value
            @config.logger.debug('splits worker not running.')
            return
          end

          return if @splits_repository.get_change_number.to_i > change_number

          @config.logger.debug("SplitsWorker kill #{split_name}, #{change_number}")
          @splits_repository.kill(change_number, split_name, default_treatment)
          add_to_queue(change_number)
        end

        private

        def perform
          while (change_number = @queue.pop)
            @config.logger.debug("SplitsWorker change_number dequeue #{change_number}")
            @synchronizer.fetch_splits(change_number)
          end
        end

        def perform_thread
          @config.threads[:split_update_worker] = Thread.new do
            @config.logger.debug('Starting splits worker ...') if @config.debug_enabled
            perform
          end
        end
      end
    end
  end
end
