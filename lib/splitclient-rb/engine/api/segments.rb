# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves segment changes from the Split Backend
    class Segments < Client
      METRICS_PREFIX = 'segmentChangeFetcher'

      def initialize(api_key, metrics, segments_repository, config)
        super(config)
        @metrics = metrics
        @api_key = api_key
        @segments_repository = segments_repository
      end

      def fetch_segments_by_names(names)
        start = Time.now

        return if names.nil? || names.empty?

        names.each do |name|
          since = @segments_repository.get_change_number(name)
          loop do
            segment = fetch_segment_changes(name, since)
            @segments_repository.add_to_segment(segment)

            @config.split_logger.log_if_debug("Segment #{name} fetched before: #{since}, \
              till: #{@segments_repository.get_change_number(name)}")

            break if since.to_i >= @segments_repository.get_change_number(name).to_i

            since = @segments_repository.get_change_number(name)
          end
        end

        latency = (Time.now - start) * 1000.0
        @metrics.time(METRICS_PREFIX + '.time', latency)
      end

      private

      def fetch_segment_changes(name, since)

        response = get_api("#{@config.base_uri}/segmentChanges/#{name}", @api_key, since: since)
        if response.success?
          segment = JSON.parse(response.body, symbolize_names: true)
          @segments_repository.set_change_number(name, segment[:till])
          @metrics.count(METRICS_PREFIX + '.status.' + response.status.to_s, 1)

          @config.split_logger.log_if_debug("\'#{segment[:name]}\' segment retrieved.")
          unless segment[:added].empty?
            @config.split_logger.log_if_debug("\'#{segment[:name]}\' #{segment[:added].size} added keys")
          end
          unless segment[:removed].empty?
            @config.split_logger.log_if_debug("\'#{segment[:name]}\' #{segment[:removed].size} removed keys")
          end
          @config.split_logger.log_if_transport("Segment changes response: #{segment.to_s}")

          segment
        elsif response.status == 403
            @config.logger.error('Factory Instantiation: You passed a browser type api_key, ' \
              'please grab an api key from the Split console that is of type sdk')
            @config.valid_mode =  false
        else
          @config.logger.error("Unexpected status code while fetching segments: #{response.status}." \
          "Since #{since} - Check your API key and base URI")
          @metrics.count(METRICS_PREFIX + '.status.' + response.status.to_s, 1)
          raise 'Split SDK failed to connect to backend to fetch segments'
        end
      end
    end
  end
end
