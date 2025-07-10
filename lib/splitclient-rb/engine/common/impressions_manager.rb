# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Common
      class ImpressionManager
        def initialize(config,
                       impressions_repository,
                       impression_counter,
                       telemetry_runtime_producer,
                       impression_observer,
                       unique_keys_tracker)
          @config = config
          @impressions_repository = impressions_repository
          @impression_counter = impression_counter
          @impression_observer = impression_observer
          @telemetry_runtime_producer = telemetry_runtime_producer
          @unique_keys_tracker = unique_keys_tracker
        end

        def build_impression(matching_key, bucketing_key, split_name, treatment_data, impressions_disabled, params = {},
                             evaluation_options = nil)
          properties = evaluation_options.nil? ? nil : evaluation_options.properties
          impression_data = impression_data(matching_key, bucketing_key, split_name, treatment_data, params[:time], properties)
          begin
            if @config.impressions_mode == :none || impressions_disabled
              @impression_counter.inc(split_name, impression_data[:m])
              @unique_keys_tracker.track(split_name, matching_key)
            elsif @config.impressions_mode == :debug #  In DEBUG mode we should calculate the pt only.
              return impression(impression_data, params[:attributes]) unless properties.nil?

              impression_data[:pt] = @impression_observer.test_and_set(impression_data)
            else # In OPTIMIZED mode we should track the total amount of evaluations and deduplicate the impressions.
              return impression(impression_data, params[:attributes]) unless properties.nil?

              impression_data[:pt] = @impression_observer.test_and_set(impression_data)
              @impression_counter.inc(split_name, impression_data[:m]) unless impression_data[:pt].nil?
            end
          rescue StandardError => e
            @config.log_found_exception(__method__.to_s, e)
          end

          impression(impression_data, params[:attributes])
        end

        def track(impressions_decorator)
          return if impressions_decorator.empty?

          impressions_decorator.each do |impression_decorator|
            impression_router.add_bulk([impression_decorator[:impression]])
            stats = { dropped: 0, queued: 0, dedupe: 0 }
            begin
              next if @config.impressions_mode == :none || impression_decorator[:disabled]

              if @config.impressions_mode == :debug
                track_debug_mode([impression_decorator[:impression]], stats)
              else
                track_optimized_mode([impression_decorator[:impression]], stats)
              end
            rescue StandardError => e
              @config.log_found_exception(__method__.to_s, e)
            ensure
              record_stats(stats)
            end
          end
        end

        private

        def impression_router
          @impression_router ||= SplitIoClient::ImpressionRouter.new(@config)
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def record_stats(stats)
          return if redis?

          imp_queued = Telemetry::Domain::Constants::IMPRESSIONS_QUEUED
          imp_dropped = Telemetry::Domain::Constants::IMPRESSIONS_DROPPED
          imp_dedupe = Telemetry::Domain::Constants::IMPRESSIONS_DEDUPE
          @telemetry_runtime_producer.record_impressions_stats(imp_queued, stats[:queued]) unless stats[:queued].zero?
          @telemetry_runtime_producer.record_impressions_stats(imp_dropped, stats[:dropped]) unless stats[:dropped].zero?
          @telemetry_runtime_producer.record_impressions_stats(imp_dedupe, stats[:dedupe]) unless stats[:dedupe].zero?
        end

        # added param time for test
        def impression_data(matching_key, bucketing_key, split_name, treatment, time = nil,
                            properties = nil)
          {
            k: matching_key,
            b: bucketing_key,
            f: split_name,
            t: treatment[:treatment],
            r: applied_rule(treatment[:label]),
            c: treatment[:change_number],
            m: time || (Time.now.to_f * 1000.0).to_i,
            pt: nil,
            properties: properties
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

        def track_debug_mode(impressions, stats)
          stats[:dropped] = @impressions_repository.add_bulk(impressions)
          stats[:queued] = impressions.length - stats[:dropped]
        end

        def track_optimized_mode(impressions, stats)
          optimized_impressions = impressions.select { |imp| should_queue_impression?(imp[:i]) }
          stats[:dedupe] = impressions.length - optimized_impressions.length
          return if optimized_impressions.empty?

          stats[:dropped] = @impressions_repository.add_bulk(optimized_impressions)
          stats[:queued] = optimized_impressions.length - stats[:dropped]
        end
      end
    end
  end
end
