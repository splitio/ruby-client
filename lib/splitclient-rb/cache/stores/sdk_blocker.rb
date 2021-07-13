require 'thread'
require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_repository

        def initialize(splits_repository, segments_repository, config)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @config = config
          @internal_ready = Concurrent::CountDownLatch.new(1)

          if @config.standalone?
            @splits_repository.not_ready!
            @segments_repository.not_ready!
          end
        end

        def splits_ready!
          if !ready?
            @splits_repository.ready!
            @config.logger.info('splits are ready')
          end
        end

        def segments_ready!
          if !ready?
            @segments_repository.ready!
            @config.logger.info('segments are ready')
          end
        end

        def block(time = nil)
          begin
            timeout = time || @config.block_until_ready
            Timeout::timeout(timeout) do
              sleep 0.1 until ready?
            end
          rescue Timeout::Error
            fail SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
          end

          @config.logger.info('SplitIO SDK is ready')
        end

        def ready?
          return true if @config.consumer?
          @splits_repository.ready? && @segments_repository.ready?
        end

        def sdk_internal_ready
          @internal_ready.count_down
        end

        def wait_unitil_internal_ready
          @internal_ready.wait
        end
      end
    end
  end
end
