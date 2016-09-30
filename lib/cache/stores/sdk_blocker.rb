require 'thread'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_mutex

        def initialize(config)
          @sdk_mutex = Mutex.new
          @sdk_condvar = ConditionVariable.new
          @splits_mutex = Mutex.new
          @splits_condvar = ConditionVariable.new

          @config = config

          @splits_ready = false
          @segments_ready = false
        end

        def splits_ready!
          @splits_ready = true

          @sdk_condvar.signal
          @splits_condvar.signal
        end

        def segments_ready!
          @segments_ready = true

          @sdk_condvar.signal
        end

        def when_ready(&block)
          @sdk_mutex.synchronize do
            until sdk_ready? do
              @sdk_condvar.wait(@sdk_mutex, @config.block_until_ready)

              raise_timeout unless sdk_ready?
            end

            block.call
          end
        end

        def wait_for_splits
          @splits_condvar.wait(@splits_mutex, @config.block_until_ready)
        end

        private

        def sdk_ready?
          ready = @splits_ready && @segments_ready

          @config.logger.info('SplitIO SDK is ready') if ready

          ready
        end

        def raise_timeout
          raise SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
        end
      end
    end
  end
end
