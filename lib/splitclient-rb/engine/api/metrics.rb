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

            result = post_api("#{SplitIoClient.configuration.events_uri}/metrics/time", @api_key, metrics_time)

            log_status(result, metrics_time.size)
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

            result = post_api("#{SplitIoClient.configuration.events_uri}/metrics/counter", @api_key, metrics_count)

            log_status(result, metrics_count.size)
          end
        end
        @metrics_repository.clear_counts
      end

      private

      def log_status(result, info_to_log)
        if result == false
          SplitIoClient.configuration.logger.error("Failed to make a http request")
        elsif (200..299).include? result.status
          SplitIoClient.configuration.logger.debug("Metric time reported: #{info_to_log}") if SplitIoClient.configuration.debug_enabled
        else
          SplitIoClient.configuration.logger.error("Unexpected status code while posting time metrics: #{result.status}")
        end
      end
    end
  end
end
