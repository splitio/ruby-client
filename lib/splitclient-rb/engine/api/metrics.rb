module SplitIoClient
  module Api
    class Metrics < Client
      def initialize(api_key, metrics_repository)
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
          SplitIoClient.configuration.logger.debug('No latencies to report.') if SplitIoClient.configuration.debug_enabled
        else
          @metrics_repository.latencies.each do |name, latencies|
            metrics_time = { name: name, latencies: latencies }

            response = post_api("#{SplitIoClient.configuration.events_uri}/metrics/time", @api_key, metrics_time)

            log_status(response, metrics_time.size)
          end
        end

        @metrics_repository.clear_latencies
      end

      def post_counts
        if @metrics_repository.counts.empty?
          SplitIoClient.configuration.logger.debug('No counts to report.') if SplitIoClient.configuration.debug_enabled
        else
          @metrics_repository.counts.each do |name, count|
            metrics_count = { name: name, delta: count }

            response = post_api("#{SplitIoClient.configuration.events_uri}/metrics/counter", @api_key, metrics_count)

            log_status(response, metrics_count.size)
          end
        end
        @metrics_repository.clear_counts
      end

      private

      def log_status(response, info_to_log)
        if response.success?
          SplitLogger.log_if_debug("Metric time reported: #{info_to_log}")
        else
          SplitLogger.log_error("Unexpected status code while posting time metrics: #{response.status}" \
          " - Check your API key and base URI")
          raise 'Split SDK failed to connect to backend to post metrics'
        end
      end
    end
  end
end
