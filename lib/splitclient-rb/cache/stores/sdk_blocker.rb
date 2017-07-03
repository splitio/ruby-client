require 'thread'
require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_repository
        attr_writer :splits_thread, :segments_thread

        def initialize(config, splits_repository, segments_repository)
          @config = config
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
            Timeout::timeout(@config.block_until_ready) do
              sleep 0.1 until ready?
            end
          rescue Timeout::Error
            fail SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
          end

          @config.logger.info('SplitIO SDK is ready')
          @splits_thread.run
          @segments_thread.run
        end

        def ready?
          @splits_repository.ready? && @segments_repository.ready?
        end
      end
    end
  end
end
