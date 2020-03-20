# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class BackOff
        def initialize(config)
          @attempt = 0
          @min_sleep_seconds = config.streaming_reconnect_back_off_base
        end

        def call
          sleep(2**@attempt) if @attempt.positive?

          @attempt += 1
        end

        def reset
          @attempt = 0
        end
      end
    end
  end
end
