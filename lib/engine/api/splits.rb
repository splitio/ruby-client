module SplitIoClient
  module Api
    class Splits < Client
      def initialize(api_key, config, metrics)
        @api_key = api_key
        @config = config
        @metrics = metrics
      end

      def since(since)
        start = Time.now
        prefix = 'splitChangeFetcher'
        splits = call_api('/splitChanges', @config, @api_key, {:since => since})

        if splits.status / 100 == 2
          result = splits_with_segment_names(splits.body)

          @metrics.count(prefix + '.status.' + splits.status.to_s, 1)

          @config.logger.info("#{result[:splits].length} splits retrieved.")
          @config.logger.debug("#{result}") if @config.debug_enabled
        else
          @metrics.count(prefix + '.status.' + splits.status.to_s, 1)

          @config.logger.error('Unexpected result from API call')
        end

        latency = (Time.now - start) * 1000.0
        @metrics.time(prefix + '.time', latency)

        result
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
