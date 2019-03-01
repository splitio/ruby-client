require 'thread'
require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_repository

        def initialize(splits_repository, segments_repository)
          @splits_repository = splits_repository
          @segments_repository = segments_repository

          @splits_repository.not_ready!
          @segments_repository.not_ready!
        end

        def splits_ready!
          @splits_repository.ready!
        end

        def segments_ready!
          @segments_repository.ready!
        end

        def block
          begin
            Timeout::timeout(SplitIoClient.configuration.block_until_ready) do
              sleep 0.1 until ready?
            end
          rescue Timeout::Error
            fail SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
          end

          SplitIoClient.configuration.logger.info('SplitIO SDK is ready')
          SplitIoClient.configuration.threads[:split_store].run
          SplitIoClient.configuration.threads[:segment_store].run
        end

        def ready?
          @splits_repository.ready? && @segments_repository.ready?
        end
      end
    end
  end
end
