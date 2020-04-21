# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class BackOff
        def initialize(back_off_base, attempt = 0)
          @attempt = attempt
          @back_off_base = back_off_base
        end

        def interval
          interval = (@back_off_base * (2**@attempt)) if @attempt.positive?
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
