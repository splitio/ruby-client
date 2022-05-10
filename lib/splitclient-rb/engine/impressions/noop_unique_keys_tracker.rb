# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Impressions
      class NoopUniqueKeysTracker
        def call
          # no-op
        end

        def track(feature_name, key)
          # no-op
        end
      end
    end
  end
end
