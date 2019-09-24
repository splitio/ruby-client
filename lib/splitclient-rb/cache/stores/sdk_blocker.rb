require 'thread'
require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        def initialize(splits_repository, segments_repository, config)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @config = config

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
          splits_ready? && @segments_repository.ready?
        end

        def splits_ready?
          @splits_repository.ready?
        end
      end
    end
  end
end
