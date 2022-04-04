# frozen_string_literal: true

require 'concurrent'

module SplitIoClient
  module Engine
    module Common
      class NoopmpressionCounter
        def inc(split_name, time_frame)
          # no-op
        end

        def pop_all
          # no-op
        end

        def make_key(split_name, time_frame)
          # no-op
        end

        def self.truncate_time_frame(timestamp_ms)
          # no-op
        end
      end
    end
  end
end
