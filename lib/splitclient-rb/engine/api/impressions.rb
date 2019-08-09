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

        impressions_by_ip(impressions).each do |ip, impressions_ip|
          response = post_api("#{@config.events_uri}/testImpressions/bulk", @api_key, impressions_ip, 'SplitSDKMachineIP' => ip)

          if response.success?
            @config.split_logger.log_if_debug("Impressions reported: #{total_impressions(impressions)}")
          else
            @config.logger.error("Unexpected status code while posting impressions: #{response.status}." \
            ' - Check your API key and base URI')
            raise 'Split SDK failed to connect to backend to post impressions'
          end
        end
      end

      def total_impressions(impressions)
        return 0 if impressions.nil?

        impressions.reduce(0) do |impressions_count, impression|
          impressions_count += impression[:keyImpressions].length
        end
      end

      private

      def impressions_by_ip(impressions)
        impressions.group_by { |impression| impression[:ip] }
      end
    end
  end
end
