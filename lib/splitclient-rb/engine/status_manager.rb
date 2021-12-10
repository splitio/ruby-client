# frozen_string_literal: true

module SplitIoClient
  module Engine
    class StatusManager
      def initialize(config)
        @config = config
        @sdk_ready = Concurrent::CountDownLatch.new(1)
      end

      def ready?
        return true if @config.consumer?

        @sdk_ready.wait(0)
      end

      def ready!
        return if ready?

        @sdk_ready.count_down
        @config.logger.info('SplitIO SDK is ready')
      end

      def wait_until_ready(seconds = nil)
        return if @config.consumer?

        timeout = seconds || @config.block_until_ready

        raise SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired' unless @sdk_ready.wait(timeout)
      end
    end
  end
end
