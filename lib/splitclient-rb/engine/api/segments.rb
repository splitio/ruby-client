module SplitIoClient
  module Api
    class Segments < Client
      def initialize(api_key, config, metrics, segments_repository)
        @config = config
        @metrics = metrics
        @api_key = api_key
        @segments_repository = segments_repository
      end

      def store_segments_by_names(names)
        start = Time.now
        prefix = 'segmentChangeFetcher'

        return if names.nil? || names.empty?

        names.each do |name|
          since = @segments_repository.get_change_number(name)
          while true
            fetch_segments(name, prefix, since).each { |segment| @segments_repository.add_to_segment(segment) }
            @config.logger.debug("Segment #{name} fetched before: #{since}, till: #{@segments_repository.get_change_number(name)}") if @config.debug_enabled

            break if (since.to_i >= @segments_repository.get_change_number(name).to_i)
            since = @segments_repository.get_change_number(name)
          end
        end

        latency = (Time.now - start) * 1000.0
        @metrics.time(prefix + '.time', latency)
      end

      private

      def fetch_segments(name, prefix, since)
        segments = []
        segment = get_api("#{@config.base_uri}/segmentChanges/#{name}", @config, @api_key, since: since)

        if segment == false
          @config.logger.error("Failed to make a http request")
        elsif segment.status / 100 == 2
          segment_content = JSON.parse(segment.body, symbolize_names: true)
          @segments_repository.set_change_number(name, segment_content[:till])
          @metrics.count(prefix + '.status.' + segment.status.to_s, 1)

          if @config.debug_enabled
            @config.logger.debug("\'#{segment_content[:name]}\' segment retrieved.")
            @config.logger.debug("\'#{segment_content[:name]}\' #{segment_content[:added].size} added keys") if segment_content[:added].size > 0
            @config.logger.debug("\'#{segment_content[:name]}\' #{segment_content[:removed].size} removed keys") if segment_content[:removed].size > 0
          end
          @config.logger.debug("#{segment_content}") if @config.transport_debug_enabled

          segments << segment_content
        else
          @config.logger.error("Unexpected result from API Call for Segment #{name} status #{segment.status.to_s} since #{since.to_s}")
          @metrics.count(prefix + '.status.' + segment.status.to_s, 1)
        end

        segments
      end
    end
  end
end
