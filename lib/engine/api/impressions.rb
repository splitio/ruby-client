module SplitIoClient
  module Api
    class Impressions < Client
      def initialize(api_key, config, impressions)
        @config = config
        @api_key = api_key
        @impressions = impressions
      end

      def post
        if @impressions.empty?
          @config.logger.debug('No impressions to report') if @config.debug_enabled
          return
        end

        result = post_api("#{config.events_uri}/testImpressions/bulk", @config, @api_key, @impressions)

        if result.status / 100 != 2
          @config.logger.error("Unexpected status code while posting impressions: #{result.status}")
        else
          @config.logger.debug("Impressions reported: #{total_impressions(@impressions)}") if @config.debug_enabled
        end
      end

      def total_impressions(impressions)
        return 0 if impressions.nil?

        impressions.reduce(0) do |impressions_count, impression|
          impressions_count += impression[:keyImpressions].length
        end
      end
    end
  end
end
