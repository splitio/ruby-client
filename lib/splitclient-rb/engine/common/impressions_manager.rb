# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Common
      class ImpressionManager
        def initialize(config, impressions_repository)
          @config = config
          @impressions_repository = impressions_repository
          @impression_router = SplitIoClient::ImpressionRouter.new(@config)
          @impression_observer = SplitIoClient::Observers::ImpressionObserver.new
        end

        # added param time for test
        def build_impression(matching_key, bucketing_key, split_name, treatment, params = {})
          impression_data = impression_data(matching_key, bucketing_key, split_name, treatment, params[:time])

          impression_data[:pt] = @impression_observer.test_and_set(impression_data) if should_add_pt

          { m: metadata, i: impression_data, attributes: params[:attributes] }
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def track(impressions)
          @impressions_repository.add_bulk(impressions)
          @impression_router.add_bulk(impressions)
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

        def should_add_pt
          @config.impressions_adapter.class.to_s != 'SplitIoClient::Cache::Adapters::RedisAdapter'
        end
      end
    end
  end
end
