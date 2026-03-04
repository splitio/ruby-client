# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Events
      class EventsTask
        attr_accessor :running

        def initialize(notify_internal_events, internal_events_queue, config)
          @notify_internal_events = notify_internal_events
          @internal_events_queue = internal_events_queue
          @config = config
          @running = false
        end

        def start
          return if @running

          @config.logger.info('Starting Internal Events Task.')
          @running = true
          @config.threads[:internal_events_task] = Thread.new do
            worker_thread
          end
        end

        def stop
          return unless @running

          @config.logger.info('Stopping Internal Events Task.')
          @running = false
        end

        private

        def worker_thread
          while (event = @internal_events_queue.pop)
            break unless @running

            @config.logger.debug("Processing sdk internal event: #{event.internal_event}") if @config.debug_enabled
            begin
              @notify_internal_events.call(event.internal_event, event.metadata)
            rescue StandardError => e
              @config.log_found_exception(__method__.to_s, e)
            end
          end
        end
      end
    end
  end
end
