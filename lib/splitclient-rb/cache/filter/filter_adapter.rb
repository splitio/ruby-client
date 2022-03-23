# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Filter
      class FilterAdapter
        def initialize(config, filter)
          @config = config
          @filter = filter
        end

        def add(feature_name, key)
          @filter.insert("#{feature_name}#{key}")
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def contains?(feature_name, key)
          @filter.include?("#{feature_name}#{key}")
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def clear
          @filter.clear
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end
      end
    end
  end
end
