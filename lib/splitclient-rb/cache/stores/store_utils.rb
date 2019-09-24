# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Stores
      class StoreUtils
        def self.random_interval(interval)
          random_factor = Random.new.rand(50..100) / 100.0

          interval * random_factor
        end
      end
    end
  end
end
