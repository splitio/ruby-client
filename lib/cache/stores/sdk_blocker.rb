require 'thread'

module SplitIoClient
  module Cache
    module Store
      class SDKBlocker
        attr_reader :mutex, :condvar

        def initialize(config, segments_repository, splits_repository)
          @mutex = Mutex.new
          @condvar = ConditionVariable.new
          @config = config
          @segments_repository = segments_repository
          @splits_repository = splits_repository
        end

        def ready?
          ready = @segments_repository.ready? && @splits_repository.ready?

          @config.logger.info('SplitIo SDK is ready') if ready

          ready
        end

        def wait(&block)
          @mutex.synchronize do
            until ready? do
              @condvar.wait(@mutex, @config.block_until_ready)
            end

            block.call
          end
        end
      end
    end
  end
end
