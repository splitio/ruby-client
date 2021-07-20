# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      BACKOFF_MAX_ALLOWED = 1.8
      class BackOff
        def initialize(back_off_base, attempt = 0, max_allowed = BACKOFF_MAX_ALLOWED)
          @attempt = attempt
          @back_off_base = back_off_base
          @max_allowed = max_allowed
        end

        def interval
          interval = 0
          interval = (@back_off_base * (2**@attempt)) if @attempt.positive?
          @attempt += 1

          interval >= @max_allowed ? @max_allowed : interval
        end

        def reset
          @attempt = 0
        end
      end
    end
  end
end
