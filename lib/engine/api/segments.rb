module SplitIoClient
  module Api
    class Segments < Client
      def initialize(api_key, config, metrics, segment_cache)
        @config = config
        @metrics = metrics
        @api_key = api_key
        @segment_cache = segment_cache
      end

      def by_names(names)
        segments = []
        start = Time.now
        prefix = 'segmentChangeFetcher'

        names.each do |name|
          curr_segment = @segment_cache.find(name)
          since = curr_segment.nil? ? -1 : curr_segment[:till]

          while true
            segments << fetch_segments(name, prefix, since)

            break if (since.to_i >= @segment_cache['since'].to_i)
            since = @segment_cache['since']
          end
        end

        latency = (Time.now - start) * 1000.0
        @metrics.time(prefix + '.time', latency)

        segments.flatten
      end

      private

      def fetch_segments(name, prefix, since)
        segments = []
        segment = call_api('/segmentChanges/' + name, @config, @api_key, { since: since })

        if segment.status / 100 == 2
          segment_content = JSON.parse(segment.body, symbolize_names: true)
          @segment_cache['since'] = segment_content[:till]
          @metrics.count(prefix + '.status.' + segment.status.to_s, 1)

          @config.logger.info("\'#{segment_content[:name]}\' segment retrieved.")
          @config.logger.debug("#{segment_content}") if @config.debug_enabled

          segments << segment_content
        else
          @config.logger.error('Unexpected result from API call')
          @metrics.count(prefix + '.status.' + segment.status.to_s, 1)
        end

        segments
      end
    end
  end
end
