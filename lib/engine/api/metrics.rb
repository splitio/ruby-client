module SplitIoClient
  module Api
    class Metrics < Client
      def initialize(api_key, config, metrics_repository)
        @config = config
        @api_key = api_key
        @metrics_repository = metrics_repository
      end

      def post
        post_latencies
        post_counts
      end

      private

      def post_latencies
        if @metrics_repository.latencies.empty?
          @config.logger.debug('No latencies to report.') if @config.debug_enabled
        else
          @metrics_repository.latencies.each do |name, latencies|
            metrics_time = { name: name, latencies: latencies }

            result = post_api("#{@config.events_uri}/metrics/time", @config, @api_key, metrics_time)

            if result.status / 100 != 2
              @config.logger.error("Unexpected status code while posting time metrics: #{result.status}")
            else
              @config.logger.debug("Metric time reported: #{metrics_time.size}") if @config.debug_enabled
            end
          end
        end

        @metrics_repository.clear_latencies
      end

      def post_counts
        if @metrics_repository.counts.empty?
          @config.logger.debug('No counts to report.') if @config.debug_enabled
        else
          @metrics_repository.counts.each do |name, count|
            metrics_count = { name: name, delta: count }

            result = post_api("#{@config.events_uri}/metrics/counter", @config, @api_key, metrics_count)

            if result.status / 100 != 2
              @config.logger.error("Unexpected status code while posting count metrics: #{result.status}")
            else
              @config.logger.debug("Metric counts reported: #{metrics_count.size}") if @config.debug_enabled
            end
          end
        end
        @metrics_repository.clear_counts
      end
    end
  end
end
