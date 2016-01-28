require "json"
require "thread"
require "faraday/http_cache"
require "bundler/vendor/net/http/persistent"


module SplitIoClient

  class SplitFetcher < NoMethodError
    attr_reader :impressions
    attr_reader :metrics
    attr_reader :parsed_splits
    attr_reader :parsed_segments
    # Creates a new split fetcher instance that consumes to split.io APIs
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config)

      @api_key = api_key
      @config = config
      @parsed_splits = SplitParser.new(@config.logger)
      @parsed_segments = SegmentParser.new(@config.logger)
      @impressions = Impressions.new(100)
      @metrics = Metrics.new(100)

      @api_client = Faraday.new do |builder|
        builder.use Faraday::HttpCache, store: @config.local_store
        builder.adapter :net_http_persistent
      end

      @consumer = create_api_consumer
      @producer = create_api_producer
    end

    def create_api_consumer
      Thread.new do
        loop do
          begin
            #splits fetch
            splits_arr = []
            data = get_splits(@parsed_splits.since)
            data[:splits].each do |split|
              splits_arr << SplitIoClient::Split.new(split)
            end

            if @parsed_splits.is_empty?
              @parsed_splits.splits = splits_arr
            else
              refresh_splits(splits_arr)
            end
            @parsed_splits.since = data[:till]

            #segments fetcher
            segments_arr =  []
            segment_data = get_segments(@parsed_splits.get_used_segments)
            segment_data.each do |segment|
              segments_arr << SplitIoClient::Segment.new(segment)
            end
            if @parsed_segments.is_empty?
              @parsed_segments.segments = segments_arr
            else
              refresh_segments(segments_arr)
            end

            sleep(@config.fetch_interval)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end


    def call_api(path, params = {})
      @api_client.get @config.base_uri + path, params do |req|
        req.headers["Authorization"] = "Bearer " + @api_key
        req.options.open_timeout = @config.connection_timeout
        req.options.timeout = @config.timeout
      end
    end

    def post_api(path, param)
      @api_client.post (@config.base_uri + path) do |req|
        req.headers["Authorization"] = "Bearer " + @api_key
        req.headers["Content-Type"] = "application/json"
        req.body = param.to_json
        req.options.timeout = @config.timeout
        req.options.open_timeout = @config.connection_timeout
      end
    end

    def get_splits(since)
      result = nil
      start = Time.now
      prefix = "splitChangeFetcher"

      splits = call_api("/splitChanges", {:since => since})

      if splits.status / 100 == 2
        result = JSON.parse(splits.body, symbolize_names: true)
        @metrics.count(prefix + ".status." + splits.status.to_s, 1)
      else
        @config.logger.error("Unexpected result from API call")
        @metrics.count(prefix + ".status." + splits.status.to_s, 1)
      end

      latency = (Time.now - start) * 1000.0
      @metrics.time(prefix + ".time", latency)

      return result
    end

    def refresh_splits(splits_arr)
      feature_names = splits_arr.map{|s| s.name}
      @parsed_splits.splits.delete_if{|sp| feature_names.include?(sp.name)}
      @parsed_splits.splits += splits_arr
    end

    def get_segments(names)
      segments = []
      start = Time.now
      prefix = "segmentChangeFetcher"

      names.each do |name|
        curr_segment = @parsed_segments.get_segment(name)
        since = curr_segment.nil? ? -1 : curr_segment.since

        segment = call_api("/segmentChanges/" + name, {:since => since})

        if segment.status / 100 == 2
          segment_content = JSON.parse(segment.body, symbolize_names: true)
          @parsed_segments.since = segment_content[:since]
          @metrics.count(prefix + ".status." + segment.status.to_s, 1)
          segments << segment_content
        else
          @config.logger.error("Unexpected result from API call")
          @metrics.count(prefix + ".status." + segment.status.to_s, 1)
        end
      end

      latency = (Time.now - start) * 1000.0
      #@metrics.time(prefix + ".time", latency)

      return segments
    end

    def refresh_segments(segments_arr)
      segment_names = segments_arr.map{|s| s.name}
      @parsed_segments.segments.delete_if{|seg| segment_names.include?(seg.name)}
      @parsed_segments.segments += segments_arr
    end


    def parsed_splits
      @parsed_splits
    end

    def parsed_segments
      @parsed_segments
    end


    def create_api_producer
      Thread.new do
        loop do
          begin
            #post captured impressions
            post_impressions
            #post captured metrics
            post_metrics
            sleep(@config.push_interval)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end

    def post_impressions
      if @impressions.queue.empty?
        @config.logger.info("No impressions to report.")
      else
        clear = true
        @impressions.queue.each do |i|
          filtered = []
          keys_seen = []

          impressions = i[:impressions]
          impressions.each do |imp|
            if keys_seen.include?(imp.key)
              next
            end
            keys_seen << imp.key
            filtered << imp
          end

          if filtered.empty?
            @config.logger.info("No impressions to report post filtering.")
          else
            test_impression = {}
            key_impressions = []

            filtered.each do |f|
              key_impressions << {keyName: f.key, treatment: f.treatment, time: f.time.to_i}
            end

            test_impression = { testName: i[:feature], keyImpressions: key_impressions }
            res = post_api("/testImpressions", test_impression)
            if res.status / 100 != 2
              @config.logger.error("Unexpected status code while posting impressions: #{res.status}")
              clear = false
            end
          end
        end
        @impressions.clear if clear
      end
    end


    def post_metrics
      clear = true
      if @metrics.latencies.empty?
         @config.logger.info("No latencies to report.")
      else
         @metrics.latencies.each do |l|
             metrics_time = {}
             metrics_time = { name: l[:operation], latencies: l[:latencies] }
             res = post_api("/metrics/time", metrics_time)
             if res.status / 100 != 2
               @config.logger.error("Unexpected status code while posting time metrics: #{res.status}")
               clear = false
             end
         end
      end
      @metrics.latencies.clear if clear

      clear = true
      if @metrics.counts.empty?
        @config.logger.info("No counts to report.")
      else
        @metrics.counts.each do |c|
          metrics_count = {}
          metrics_count = { name: c[:name], delta: c[:delta].sum }
          res = post_api("/metrics/count", metrics_count)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting count metrics: #{res.status}")
            clear = false
          end
        end
      end
      @metrics.counts.clear if clear

      clear = true
      if @metrics.gauges.empty?
        @config.logger.info("No gauges to report.")
      else
        @metrics.gauges.each do |g|
          metrics_gauge = {}
          metrics_gauge = { name: g[:name], value: g[:gauge].value }
          res = post_api("/metrics/gauge", metrics_gauge)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting gauge metrics: #{res.status}")
            clear = false
          end
        end
      end
      @metrics.gauges.clear if clear

    end

  end
end