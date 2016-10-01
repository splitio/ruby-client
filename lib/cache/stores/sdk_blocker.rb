require 'thread'
require 'timeout'

module SplitIoClient
  module Cache
    module Stores
      class SDKBlocker
        attr_reader :splits_ready
        attr_writer :splits_thread, :segments_thread

        def initialize(config)
          @config = config

          @splits_ready = false
          @segments_ready = false
        end

        def splits_ready!
          @splits_ready = true
        end

        def segments_ready!
          @segments_ready = true
        end

        def block
          begin
            Timeout::timeout(@config.block_until_ready) do
              sleep 0.1 until ready?
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
          @splits_ready && @segments_ready
        end
      end
    end
  end
end
