# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class BackOff
        def initialize(config)
          @config = config
          @attempt = 0
        end

        def interval
          interval = (@config.streaming_reconnect_back_off_base * (2**@attempt)) if @attempt.positive?
          @attempt += 1

          interval || 0
        end

        def reset
          @attempt = 0
        end
      end
    end
  end
end
