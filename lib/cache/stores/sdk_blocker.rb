require 'thread'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_mutex
        attr_writer :splits_thread, :segments_thread

        def initialize(config)
          @splits_mutex = Mutex.new
          @splits_condvar = ConditionVariable.new

          @config = config

          @splits_ready = false
          @segments_ready = false
        end

        def splits_ready!
          @splits_ready = true

          @splits_condvar.signal
        end

        def segments_ready!
          @segments_ready = true
        end

        def when_ready(&block)
          @splits_thread.join(@config.block_until_ready)
          @segments_thread.join(@config.block_until_ready)

          raise SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired' unless ready?

          block.call
        end

        def wait_for_splits
          @splits_condvar.wait(@splits_mutex, @config.block_until_ready)
        end

        def ready?
          ready = @splits_ready && @segments_ready

          @config.logger.info('SplitIO SDK is ready') if ready

          ready
        end
      end
    end
  end
end
