# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SegmentsWorker
        def initialize(synchronizer, config, segments_repository)
          @synchronizer = synchronizer
          @config = config
          @segments_repository = segments_repository
          @queue = nil
        end

        def start
          return if SplitIoClient::Helpers::ThreadHelper.alive?(:segment_update_worker, @config)

          @queue = Queue.new
          perform_thread
        end

        def add_to_queue(change_number, segment_name)
          return if @queue.nil?

          item = { change_number: change_number, segment_name: segment_name }
          @config.logger.debug("SegmentsWorker add to queue #{item}")
          @queue.push(item)
        end

        def stop
          SplitIoClient::Helpers::ThreadHelper.stop(:segment_update_worker, @config)
          @queue = nil
        end

        private

        def perform
          while (item = @queue.pop)
            segment_name = item[:segment_name]
            change_number = item[:change_number]
            since = @segments_repository.get_change_number(segment_name)

            unless since >= change_number
              @config.logger.debug("SegmentsWorker fetch_segment with #{since}")
              @synchronizer.fetch_segment(segment_name)
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
