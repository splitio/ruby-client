# frozen_string_literal: true

module SplitIoClient
  module Api
    class Impressions < Client
      def initialize(api_key, config)
        @api_key = api_key
        @config = config
      end

      def post(impressions)
        if impressions.empty?
          @config.split_logger.log_if_debug('No impressions to report')
          return
        end

        response = post_api("#{@config.events_uri}/testImpressions/bulk", @api_key, impressions, impressions_headers)

        if response.success?
          @config.split_logger.log_if_debug("Impressions reported: #{total_impressions(impressions)}")
        else
          @config.logger.error("Unexpected status code while posting impressions: #{response.status}." \
          ' - Check your API key and base URI')
          raise 'Split SDK failed to connect to backend to post impressions'
        end
      end

      def post_count(impressions_count)
        if impressions_count.nil? || impressions_count[:pf].empty?
          @config.split_logger.log_if_debug('No impressions count to report')
          return
        end

        response = post_api("#{@config.events_uri}/testImpressions/count", @api_key, impressions_count)

        if response.success?
          @config.split_logger.log_if_debug("Impressions reported: #{impressions_count[:pf].length}")
        else
          @config.logger.error("Unexpected status code while posting impressions: #{response.status}." \
          ' - Check your API key and base URI')
          raise 'Split SDK failed to connect to backend to post impressions'
        end
      end

      def total_impressions(impressions)
        return 0 if impressions.nil?

        impressions.reduce(0) do |impressions_count, impression|
          impressions_count += impression[:i].length
        end
      end

      private

      def impressions_headers
        {
          'SplitImpressionsMode' => @config.impressions_mode.to_s
        }
      end
    end
  end
end
