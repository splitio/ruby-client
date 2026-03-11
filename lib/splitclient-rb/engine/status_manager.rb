# frozen_string_literal: true
require_relative './models/sdk_internal_event_notification.rb'
require_relative './models/sdk_internal_event.rb'

module SplitIoClient
  module Engine
    class StatusManager
      def initialize(config, internal_events_queue)
        @config = config
        @sdk_ready = Concurrent::CountDownLatch.new(1)
        @internal_events_queue = internal_events_queue
      end

      def ready?
        return true if @config.consumer?

        @sdk_ready.wait(0)
      end

      def ready!
        return if ready?

        @sdk_ready.count_down
        @config.logger.info('SplitIO SDK is ready')
        @internal_events_queue.push(
          SdkInternalEventNotification.new(
            SdkInternalEvent::SDK_READY, nil
          )
        )
      end

      def wait_until_ready(seconds = nil)
        return if @config.consumer?

        timeout = seconds || @config.block_until_ready

        raise SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired' unless @sdk_ready.wait(timeout)
      end
    end
  end
end
