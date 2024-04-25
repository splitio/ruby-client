# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class Splits < Client

      def initialize(api_key, config, telemetry_runtime_producer)
        super(config)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
        @flag_sets_filter = @config.flag_sets_filter
      end

      def since(since, fetch_options = { cache_control_headers: false, till: nil, sets: nil})
        start = Time.now

        params = { s: SplitIoClient::Spec::FeatureFlags::SPEC_VERSION, since: since }
        params[:till] = fetch_options[:till] unless fetch_options[:till].nil?
        params[:sets] = @flag_sets_filter.join(",") unless @flag_sets_filter.empty?
        @config.logger.debug("Fetching from splitChanges with #{params}: ")
        response = get_api("#{@config.base_uri}/splitChanges", @api_key, params, fetch_options[:cache_control_headers])
        if response.status == 414
          @config.logger.error("Error fetching feature flags; the amount of flag sets provided are too big, causing uri length error.")
          raise ApiException.new response.body, 414
        end
        if response.success?
          result = splits_with_segment_names(response.body)
          unless result[:splits].empty?
            @config.split_logger.log_if_debug("#{result[:splits].length} feature flags retrieved. since=#{since}")
          end
          @config.split_logger.log_if_transport("Feature flag changes response: #{result.to_s}")

          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::SPLIT_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::SPLIT_SYNC, (Time.now.to_f * 1000.0).to_i)

          result
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::SPLIT_SYNC, response.status)

          @config.logger.error("Unexpected status code while fetching feature flags: #{response.status}. " \
          'Check your API key and base URI')

          raise 'Split SDK failed to connect to backend to fetch feature flags definitions'
        end
      end

      private

      def splits_with_segment_names(splits_json)
        parsed_splits = JSON.parse(splits_json, symbolize_names: true)

        parsed_splits[:segment_names] =
          parsed_splits[:splits].each_with_object(Set.new) do |split, splits|
            splits << Helpers::Util.segment_names_by_feature_flag(split)
          end.flatten

        parsed_splits
      end
    end
  end
end
