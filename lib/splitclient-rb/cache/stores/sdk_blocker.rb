# frozen_string_literal: true

require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        def initialize(splits_repository, segments_repository, config)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @config = config

          return unless @config.standalone?

          @splits_repository.not_ready!
          @segments_repository.not_ready!
        end

        def splits_ready!
          return if ready?

          @splits_repository.ready!
          @config.logger.info('splits are ready')
        end

        def segments_ready!
          return if ready?

          @segments_repository.ready!
          @config.logger.info('segments are ready')
        end

        def block(time = nil)
          begin
            timeout = time || @config.block_until_ready
            Timeout.timeout(timeout) do
              sleep 0.1 until ready?
            end
          rescue Timeout::Error
            raise SDKBlockerTimeoutExpiredException, 'SDK start up timeout expired'
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
