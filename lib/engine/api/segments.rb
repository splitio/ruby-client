module SplitIoClient
  module Api
    class Segments < Client
      def initialize(api_key, config, metrics)
        @config = config
        @metrics = metrics
        @api_key = api_key
      end

      def by_names(names)
        segments = []
        start = Time.now
        prefix = 'segmentChangeFetcher'

        names.each do |name|
          curr_segment = @parsed_segments.get_segment(name)
          since = curr_segment.nil? ? -1 : curr_segment.till

          while true
            segment = call_api('/segmentChanges/' + name, @config, @api_key, {:since => since})

            if segment.status / 100 == 2
              segment_content = JSON.parse(segment.body, symbolize_names: true)
              @parsed_segments.since = segment_content[:till]
              @metrics.count(prefix + '.status.' + segment.status.to_s, 1)

              @config.logger.info("\'#{segment_content[:name]}\' segment retrieved.")
              @config.logger.debug("#{segment_content}") if @config.debug_enabled

              segments << segment_content
            else
              @config.logger.error('Unexpected result from API call')
              @metrics.count(prefix + '.status.' + segment.status.to_s, 1)
            end
            break if (since.to_i >= @parsed_segments.since.to_i)
            since = @parsed_segments.since
          end
        end

        latency = (Time.now - start) * 1000.0
        @metrics.time(prefix + '.time', latency)

        segments
      end
    end
  end
end
