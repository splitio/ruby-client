# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Common
      class ImpressionManager
        def initialize(config, impressions_repository)
          @config = config
          @impressions_repository = impressions_repository
          @impression_router = SplitIoClient::ImpressionRouter.new(@config)
          # @impression_observer = impression_observer
        end

        def add_to_queue(impressions, matching_key, bucketing_key, split_name, treatment, attributes)
          imp = build_impression(matching_key, bucketing_key, split_name, treatment, attributes)

          impressions << imp
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def track(impressions)
          @impressions_repository.add_bulk_v2(impressions)
          @impression_router.add_bulk_v2(impressions)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        private

        def build_impression(matching_key, bucketing_key, split_name, treatment, attributes)
          impression_data = impression_data(matching_key, bucketing_key, split_name, treatment)
          # impression_data[:pt] = @impression_observer.test_and_set(impression)

          { m: metadata, i: impression_data, attributes: attributes }
        end

        def impression_data(matching_key, bucketing_key, split_name, treatment)
          {
            k: matching_key,
            b: bucketing_key,
            f: split_name,
            t: treatment[:treatment],
            r: applied_rule(treatment[:label]),
            c: treatment[:change_number],
            m: (Time.now.to_f * 1000.0).to_i,
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
      end
    end
  end
end
