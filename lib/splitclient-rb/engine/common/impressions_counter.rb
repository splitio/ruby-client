# frozen_string_literal: true

require 'concurrent'

module SplitIoClient
  module Engine
    module Common
      TIME_INTERVAL_MS = 3600 * 1000

      class ImpressionCounter
        DEFAULT_AMOUNT = 1

        def initialize
          @cache = Concurrent::Hash.new
        end

        def inc(split_name, time_frame)
          key = make_key(split_name, time_frame)

          current_amount = @cache[key]
          @cache[key] = current_amount.nil? ? DEFAULT_AMOUNT : (current_amount + DEFAULT_AMOUNT)
        end

        def pop_all
          to_return = Concurrent::Hash.new

          @cache.each do |key, value|
            to_return[key] = value
          end
          @cache.clear

          to_return
        end

        def truncate_time_frame(timestamp_ms)
          timestamp_ms - (timestamp_ms % TIME_INTERVAL_MS)
        end

        def make_key(split_name, time_frame)
          "#{split_name}::#{truncate_time_frame(time_frame)}"
        end
      end
    end
  end
end
