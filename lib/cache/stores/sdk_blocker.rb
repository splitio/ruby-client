require 'thread'
require 'timeout'

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
          unless ready?
            begin
              Timeout::timeout(@config.block_until_ready) do
                @splits_thread.join
                @segments_thread.join
              end
            rescue Timeout::Error
              fail SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
            end

            @config.logger.info('SplitIO SDK is ready')
            @splits_thread.wakeup
            @segments_thread.wakeup
          end
          block.call
        end

        def wait_for_splits
          @splits_condvar.wait(@splits_mutex, @config.block_until_ready)
        end

        def ready?
          @splits_ready && @segments_ready
        end
      end
    end
  end
end
