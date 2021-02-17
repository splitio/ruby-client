# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SegmentsWorker
        def initialize(synchronizer, config, segments_repository)
          @synchronizer = synchronizer
          @config = config
          @segments_repository = segments_repository
          @queue = Queue.new
          @running = Concurrent::AtomicBoolean.new(false)
        end

        def add_to_queue(change_number, segment_name)
          unless @running.value
            @config.logger.debug('segments worker not running.')
            return
          end

          item = { change_number: change_number, segment_name: segment_name }
          @config.logger.debug("SegmentsWorker add to queue #{item}")
          @queue.push(item)
        end

        def start
          if @running.value
            @config.logger.debug('segments worker already running.')
            return
          end

          @running.make_true
          perform_thread
        end

        def stop
          unless @running.value
            @config.logger.debug('segments worker not running.')
            return
          end

          @running.make_false
          SplitIoClient::Helpers::ThreadHelper.stop(:segment_update_worker, @config)
        end

        private

        def perform
          while (item = @queue.pop)
            segment_name = item[:segment_name]
            change_number = item[:change_number]
            @config.logger.debug("SegmentsWorker change_number dequeue #{segment_name}, #{change_number}")

            attempt = 0
            while change_number > @segments_repository.get_change_number(segment_name).to_i && attempt <= Workers::MAX_RETRIES_ALLOWED
              @synchronizer.fetch_segment(segment_name)
              attempt += 1
            end
          end
        end

        def perform_thread
          @config.threads[:segment_update_worker] = Thread.new do
            @config.logger.debug('Starting segments worker ...') if @config.debug_enabled
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
