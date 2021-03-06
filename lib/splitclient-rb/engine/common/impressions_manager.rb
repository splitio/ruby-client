# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Common
      class ImpressionManager
        def initialize(config, impressions_repository, impression_counter)
          @config = config
          @impressions_repository = impressions_repository
          @impression_counter = impression_counter
          @impression_observer = SplitIoClient::Observers::ImpressionObserver.new
        end

        # added param time for test
        def build_impression(matching_key, bucketing_key, split_name, treatment, params = {})
          impression_data = impression_data(matching_key, bucketing_key, split_name, treatment, params[:time])

          impression_data[:pt] = @impression_observer.test_and_set(impression_data) unless redis?

          @impression_counter.inc(split_name, impression_data[:m]) if optimized? && !redis?

          impression(impression_data, params[:attributes])
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def track(impressions)
          return if impressions.empty?

          impression_router.add_bulk(impressions)

          if optimized? && !redis?
            optimized_impressions = impressions.select { |imp| should_queue_impression?(imp[:i]) }
            @impressions_repository.add_bulk(optimized_impressions)
          else
            @impressions_repository.add_bulk(impressions)
          end
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        private

        # added param time for test
        def impression_data(matching_key, bucketing_key, split_name, treatment, time = nil)
          {
            k: matching_key,
            b: bucketing_key,
            f: split_name,
            t: treatment[:treatment],
            r: applied_rule(treatment[:label]),
            c: treatment[:change_number],
            m: time || (Time.now.to_f * 1000.0).to_i,
            pt: nil
          }
        end

        def metadata
          {
            s: "#{@config.language}-#{@config.version}",
            i: @config.machine_ip,
            n: @config.machine_name
          }
        end

        def applied_rule(label)
          @config.labels_enabled ? label : nil
        end

        def optimized?
          @config.impressions_mode == :optimized
        end

        def should_queue_impression?(impression)
          impression[:pt].nil? ||
            (ImpressionCounter.truncate_time_frame(impression[:pt]) != ImpressionCounter.truncate_time_frame(impression[:m]))
        end

        def impression(impression_data, attributes)
          { m: metadata, i: impression_data, attributes: attributes }
        end

        def redis?
          @config.impressions_adapter.class.to_s == 'SplitIoClient::Cache::Adapters::RedisAdapter'
        end

        def impression_router
          @impression_router ||= SplitIoClient::ImpressionRouter.new(@config)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
