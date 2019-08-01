# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class Splits < Client
      METRICS_PREFIX = 'splitChangeFetcher'

      def initialize(api_key, metrics, config)
        super(config)
        @api_key = api_key
        @metrics = metrics
      end

      def since(since)
        start = Time.now

        response = get_api("#{@config.base_uri}/splitChanges", @api_key, since: since)

        if response.success?
          result = splits_with_segment_names(response.body)

          @metrics.count(METRICS_PREFIX + '.status.' + response.status.to_s, 1)
          unless result[:splits].empty?
            @config.split_logger.log_if_debug("#{result[:splits].length} splits retrieved. since=#{since}")
          end
          @config.split_logger.log_if_transport(result.to_s)

          latency = (Time.now - start) * 1000.0
          @metrics.time(METRICS_PREFIX + '.time', latency)

          result
        else
          @metrics.count(METRICS_PREFIX + '.status.' + response.status.to_s, 1)
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
