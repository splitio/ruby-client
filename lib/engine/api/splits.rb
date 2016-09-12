module SplitIoClient
  module Api
    class Splits < Client
      def initialize(api_key, config, metrics)
        @config = config
        @metrics = metrics
        @api_key = api_key
      end

      def since(since)
        start = Time.now
        prefix = 'splitChangeFetcher'
        splits = call_api('/splitChanges', @config, @api_key, {:since => since})

        if splits.status / 100 == 2
          result = JSON.parse(splits.body, symbolize_names: true)
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
    end
  end
end
