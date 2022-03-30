# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class MemoryImpressionsSender < ImpressionsSenderAdapter
        def initialize(config, telemetry_api, impressions_api)
          @config = config
          @telemetry_api = telemetry_api
          @impressions_api = impressions_api
        end

        def record_uniques_key(uniques)
          uniques_keys = uniques_formatter(uniques)

          @telemetry_api.record_unique_keys(uniques_keys) unless uniques_keys.nil?
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def record_impressions_count(impressions_count)
          counts = impressions_count_formatter(impressions_count)

          @impressions_api.post_count(counts) unless counts.nil?
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
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

        def impressions_count_formatter(counts)
          return if counts.empty?

          formated_counts = {pf: []}

          counts.each do |key, value|              
            key_splited = key.split('::')
            
            formated_counts[:pf] << {
              f: key_splited[0].to_s, # feature name
              m: key_splited[1].to_i, # time frame
              rc: value # count
            }
          end

          formated_counts
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
          nil
        end
      end
    end
  end
end
