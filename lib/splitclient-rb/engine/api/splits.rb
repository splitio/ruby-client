# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class Splits < Client

      PROXY_CHECK_INTERVAL_SECONDS = 24 * 60 * 60
      SPEC_1_1 = "1.1"

      def initialize(api_key, config, telemetry_runtime_producer)
        super(config)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
        @flag_sets_filter = @config.flag_sets_filter
        @spec_version = SplitIoClient::Spec::FeatureFlags::SPEC_VERSION
        @last_proxy_check_timestamp = 0
        @clear_storage = false
      end

      def since(since, since_rbs, fetch_options = { cache_control_headers: false, till: nil, sets: nil})
        start = Time.now
        
        if check_last_proxy_check_timestamp
            puts "switching to new spec"
            @spec_version = SplitIoClient::Spec::FeatureFlags::SPEC_VERSION
            @config.logger.debug("Switching to new Feature flag spec #{@spec_version} and fetching.")
            since = -1
            since_rbs = -1
            fetch_options = { cache_control_headers: false, till: nil, sets: nil}
        end

        if @spec_version == Splits::SPEC_1_1
          params = { s: @spec_version, since: since }
        else
          params = { s: @spec_version, since: since, rbSince: since_rbs }
        end

        params[:sets] = @flag_sets_filter.join(",") unless @flag_sets_filter.empty?
        params[:till] = fetch_options[:till] unless fetch_options[:till].nil?
        @config.logger.debug("Fetching from splitChanges with #{params}: ")
        response = get_api("#{@config.base_uri}/splitChanges", @api_key, params, fetch_options[:cache_control_headers])

        if response.status == 414
          @config.logger.error("Error fetching feature flags; the amount of flag sets provided are too big, causing uri length error.")
          raise ApiException.new response.body, 414
        end

        if response.status == 400 and sdk_url_overriden? and @spec_version == SplitIoClient::Spec::FeatureFlags::SPEC_VERSION
            @config.logger.warn("Detected proxy response error, changing spec version from #{@spec_version} to #{Splits::SPEC_1_1} and re-fetching.")
            @spec_version = Splits::SPEC_1_1
            @last_proxy_check_timestamp = Time.now
            return since(since, 0, fetch_options = {cache_control_headers: fetch_options[:cache_control_headers], till: fetch_options[:till],
                sets: fetch_options[:sets]})          
        end

        if response.success?
          result = JSON.parse(response.body, symbolize_names: true)
          if @spec_version == Splits::SPEC_1_1
            result = convert_to_newSPEC(result)
          end
          
          result = objects_with_segment_names(result)
          
          if @spec_version == SplitIoClient::Spec::FeatureFlags::SPEC_VERSION
            @clear_storage = @last_proxy_check_timestamp != 0
            @last_proxy_check_timestamp = 0
          end

          unless result[:ff][:d].empty?
            @config.split_logger.log_if_debug("#{result[:ff][:d].length} feature flags retrieved. since=#{since}")
          end
          @config.split_logger.log_if_transport("Feature flag changes response: #{result[:ff].to_s}")

          unless result[:rbs][:d].empty?
            @config.split_logger.log_if_debug("#{result[:rbs][:d].length} rule based segments retrieved. since=#{since_rbs}")
          end
          @config.split_logger.log_if_transport("rule based segments changes response: #{result[:rbs].to_s}")

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

      def clear_storage
        @clear_storage
      end

      private

      def objects_with_segment_names(parsed_objects)
        parsed_objects[:segment_names] = Set.new
        parsed_objects[:segment_names] =
          parsed_objects[:ff][:d].each_with_object(Set.new) do |split, splits|
            splits << Helpers::Util.segment_names_by_object(split, "IN_SEGMENT")
          end.flatten

        parsed_objects[:rbs][:d].each do |rule_based_segment|
          parsed_objects[:segment_names].merge Helpers::Util.segment_names_by_object(rule_based_segment, "IN_SEGMENT")
        end

        parsed_objects[:rbs][:d].each do |rule_based_segment| 
          rule_based_segment[:excluded][:segments].each do |segment|
            if segment[:type] == "standard"
              parsed_objects[:segment_names].add(segment[:name])
            end
          end
        end
        
        parsed_objects
      end

      def check_last_proxy_check_timestamp
        @spec_version == Splits::SPEC_1_1 and ((Time.now - @last_proxy_check_timestamp) >= Splits::PROXY_CHECK_INTERVAL_SECONDS)
      end

      def convert_to_newSPEC(body)
        {:ff => {:d => body[:splits], :s => body[:since], :t => body[:till]}, :rbs => {:d => [], :s => -1, :t => -1}}
      end
    end
  end
end
