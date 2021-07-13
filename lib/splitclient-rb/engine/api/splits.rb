# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class Splits < Client
      def initialize(api_key, config, telemetry_runtime_producer)
        super(config)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def since(since, cache_control_headers = false)
        start = Time.now

        response = get_api("#{@config.base_uri}/splitChanges", @api_key, { since: since }, cache_control_headers)
        if response.success?
          result = splits_with_segment_names(response.body)

          unless result[:splits].empty?
            @config.split_logger.log_if_debug("#{result[:splits].length} splits retrieved. since=#{since}")
          end
          @config.split_logger.log_if_transport("Split changes response: #{result.to_s}")

          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::SPLIT_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::SPLIT_SYNC, (Time.now.to_f * 1000.0).to_i)

          result
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::SPLIT_SYNC, response.status)

          @config.logger.error("Unexpected status code while fetching splits: #{response.status}. " \
          'Check your API key and base URI')

          raise 'Split SDK failed to connect to backend to fetch split definitions'
        end
      end

      private

      def splits_with_segment_names(splits_json)
        parsed_splits = JSON.parse(splits_json, symbolize_names: true)

        parsed_splits[:segment_names] =
          parsed_splits[:splits].each_with_object(Set.new) do |split, splits|
            splits << segment_names(split)
          end.flatten

        parsed_splits
      end

      def segment_names(split)
        split[:conditions].each_with_object(Set.new) do |condition, names|
          condition[:matcherGroup][:matchers].each do |matcher|
            next if matcher[:userDefinedSegmentMatcherData].nil?

            names << matcher[:userDefinedSegmentMatcherData][:segmentName]
          end
        end
      end
    end
  end
end
