# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class MemoryUniqueKeysSender < UniqueKeysSenderAdapter
        def initialize(config, telemetry_api)
          @config = config
          @telemetry_api = telemetry_api
        end

        def record_uniques_key(uniques)
          uniques_keys = uniques_formatter(uniques)

          @telemetry_api.record_unique_keys(uniques_keys) unless uniques_keys.nil?
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def record_impressions_count
          # TODO: implementation
        end

        private 

        def uniques_formatter(uniques)
          return if uniques.empty?

          to_return = { mtks: [] }
          uniques.each do |key, value|
            to_return[:mtks] << {
              f: key,
              ks: value.to_a
            }
          end

          to_return
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
          nil
        end
      end
    end
  end
end
