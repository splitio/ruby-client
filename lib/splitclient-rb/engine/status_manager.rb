# frozen_string_literal: true

module SplitIoClient
  module Engine
    class StatusManager
      def initialize(config)
        @config = config
        @sdk_ready = Concurrent::CountDownLatch.new(1)
      end

      def ready?
        @sdk_ready.wait(0)
      end

      def ready!
        return if ready?

        @sdk_ready.count_down
        @config.logger.info('SplitIO SDK is ready')
      end

      def wait_until_ready(seconds)
        @sdk_ready.wait(seconds)
      end
    end
  end
end
