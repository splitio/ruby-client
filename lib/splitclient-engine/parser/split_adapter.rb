require 'json'
require 'thread'
require 'faraday/http_cache'
require 'bundler/vendor/net/http/persistent'
require 'faraday_middleware'


module SplitIoClient

  #
  # acts as an api adapater to connect to split endpoints
  # uses a configuration object that can be modified when creating the client instance
  # also, uses safe threads to execute fetches and post give the time execution values from the config
  #
  class SplitAdapter < NoMethodError
    #
    # handler for impressions
    attr_reader :impressions

    #
    # handler for metrics
    attr_reader :metrics

    #
    # handler for parsed splits
    attr_reader :parsed_splits

    #
    # handeler for parsed segments
    attr_reader :parsed_segments

    #
    # Creates a new split api adapter instance that consumes split api endpoints
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
        builder.use FaradayMiddleware::Gzip
        builder.adapter :net_http_persistent
      end

      @consumer = create_api_consumer
      @producer = create_api_producer
    end

    #
    # creates a safe thread that will be executing api calls
    # for fetching splits and segments give the execution time
    # provided within the configuration
    #
    # @return [void]
    def create_api_consumer
      Thread.new do
        loop do
          begin
            #splits fetcher
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
            segments_arr = []
            segment_data = get_segments(@parsed_splits.get_used_segments)
            segment_data.each do |segment|
              segments_arr << SplitIoClient::Segment.new(segment)
            end
            if @parsed_segments.is_empty?
              @parsed_segments.segments = segments_arr
              @parsed_segments.segments.map { |s| s.refresh_users(s.added, s.removed) }
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

    #
    # helper method to execute a get request to the provided endpoint
    #
    # @param path [string] api endpoint path
    # @param params [object] hash of params that will be added to the request
    #
    # @return [object] response to the request
    def call_api(path, params = {})
      @api_client.get @config.base_uri + path, params do |req|
        req.headers['Authorization'] = 'Bearer ' + @api_key
        req.headers['SplitSDKVersion'] = SplitIoClient::SplitClient.sdk_version
        req.headers['SplitSDKMachineName'] = @config.machine_name
        req.headers['SplitSDKMachineIP'] = @config.machine_ip
        req.headers['Accept-Encoding'] = 'gzip'
        req.options.open_timeout = @config.connection_timeout
        req.options.timeout = @config.timeout
        @config.logger.debug("GET #{@config.base_uri + path}") if @config.debug_enabled
      end
    end

    #
    # helper method to execute a post request to the provided endpoint
    #
    # @param path [string] api endpoint path
    # @param params [object] hash of params that will be added to the request
    #
    # @return [object] response to the request
    def post_api(path, param)
      @api_client.post (@config.base_uri + path) do |req|
        req.headers['Authorization'] = 'Bearer ' + @api_key
        req.headers['Content-Type'] = 'application/json'
        req.headers['SplitSDKVersion'] = SplitIoClient::SplitClient.sdk_version
        req.headers['SplitSDKMachineName'] = @config.machine_name
        req.headers['SplitSDKMachineIP'] = @config.machine_ip
        req.body = param.to_json
        req.options.timeout = @config.timeout
        req.options.open_timeout = @config.connection_timeout
        @config.logger.debug("POST #{@config.base_uri + path} #{req.body}") if @config.debug_enabled
      end
    end

    #
    # helper method to fetch splits by using the appropriate api endpoint
    #
    # @param since [int] since value for the last fetch
    #
    # @return splits [object] splits structure in json format
    def get_splits(since)
      result = nil
      start = Time.now
      prefix = 'splitChangeFetcher'

      splits = call_api('/splitChanges', {:since => since})

      if splits.status / 100 == 2
        result = JSON.parse(splits.body, symbolize_names: true)
        @metrics.count(prefix + '.status.' + splits.status.to_s, 1)
        @config.logger.info("#{result[:splits].length} splits retrieved.")
        @config.logger.debug("#{result}") if @config.debug_enabled
      else
        @config.logger.error('Unexpected result from API call')
        @metrics.count(prefix + '.status.' + splits.status.to_s, 1)
      end

      latency = (Time.now - start) * 1000.0
      @metrics.time(prefix + '.time', latency)

      result
    end

    #
    # helper method to refresh splits values after a new fetch with changes
    #
    # @param splits_arr [object] array of splits to refresh
    #
    # @return [void]
    def refresh_splits(splits_arr)
      feature_names = splits_arr.map { |s| s.name }
      @parsed_splits.splits.delete_if { |sp| feature_names.include?(sp.name) }
      @parsed_splits.splits += splits_arr
    end

    #
    # helper method to fetch segments by using the appropriate api endpoint
    #
    # @param names [object] array of segment names that must be fetched
    #
    # @return segments [object] segments structure in json format
    def get_segments(names)
      segments = []
      start = Time.now
      prefix = 'segmentChangeFetcher'

      names.each do |name|
        curr_segment = @parsed_segments.get_segment(name)
        since = curr_segment.nil? ? -1 : curr_segment.till

        while true
          segment = call_api('/segmentChanges/' + name, {:since => since})

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

    #
    # helper method to refresh segments values after a new fetch with changes
    #
    # @param segments_arr [object] array of segments to refresh
    #
    # @return [void]
    def refresh_segments(segments_arr)
      segment_names = @parsed_segments.segments.map { |s| s.name }
      segments_arr.each do |s|
        if segment_names.include?(s.name)
          segment_to_update = @parsed_segments.get_segment(s.name)
          segment_to_update.refresh_users(s.added, s.removed)
        else
          @parsed_segments.segments << s
        end
      end
    end


    #
    # @return parsed_splits [object] parsed splits for this adapter
    def parsed_splits
      @parsed_splits
    end

    #
    # @return parsed_segments [object] parsed segments for this adapter
    def parsed_segments
      @parsed_segments
    end

    #
    # creates a safe thread that will be executing api calls
    # for posting impressions and metrics given the execution time
    # provided within the configuration
    #
    # @return [void]
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

    #
    # creates the appropriate json data for the cached impressions values
    # and then sends them to the appropriate api endpoint with a valid body format
    #
    # @return [void]
    def post_impressions
      if @impressions.queue.empty?
        @config.logger.info('No impressions to report.')
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
            @config.logger.info('No impressions to report post filtering.')
          else
            test_impression = {}
            key_impressions = []

            filtered.each do |f|
              key_impressions << {keyName: f.key, treatment: f.treatment, time: f.time.to_i}
            end

            test_impression = {testName: i[:feature], keyImpressions: key_impressions}
            res = post_api('/testImpressions', test_impression)
            if res.status / 100 != 2
              @config.logger.error("Unexpected status code while posting impressions: #{res.status}")
              clear = false
            else
              @config.logger.info("Impressions reported.")
              @config.logger.debug("#{test_impression}")if @config.debug_enabled
            end
          end
        end
        @impressions.clear if clear
      end
    end

    #
    # creates the appropriate json data for the cached metrics values
    # include latencies, counts and gauges
    # and then sends them to the appropriate api endpoint with a valida body format
    #
    # @return [void]
    def post_metrics
      clear = true
      if @metrics.latencies.empty?
        @config.logger.info('No latencies to report.')
      else
        @metrics.latencies.each do |l|
          metrics_time = {}
          metrics_time = {name: l[:operation], latencies: l[:latencies]}
          res = post_api('/metrics/time', metrics_time)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting time metrics: #{res.status}")
            clear = false
          else
            @config.logger.info("Metric time reported.")
            @config.logger.debug("#{metrics_time}") if @config.debug_enabled
          end
        end
      end
      @metrics.latencies.clear if clear

      clear = true
      if @metrics.counts.empty?
        @config.logger.info('No counts to report.')
      else
        @metrics.counts.each do |c|
          metrics_count = {}
          metrics_count = {name: c[:name], delta: c[:delta].sum}
          res = post_api('/metrics/counter', metrics_count)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting count metrics: #{res.status}")
            clear = false
          else
            @config.logger.info("Metric counts reported.")
            @config.logger.debug("#{metrics_count}") if @config.debug_enabled
          end
        end
      end
      @metrics.counts.clear if clear

      clear = true
      if @metrics.gauges.empty?
        @config.logger.info('No gauges to report.')
      else
        @metrics.gauges.each do |g|
          metrics_gauge = {}
          metrics_gauge = {name: g[:name], value: g[:gauge].value}
          res = post_api('/metrics/gauge', metrics_gauge)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting gauge metrics: #{res.status}")
            clear = false
          else
            @config.logger.info("Metric gauge reported.")
            @config.logger.debug("#{metrics_gauge}") if @config.debug_enabled
          end
        end
      end
      @metrics.gauges.clear if clear

    end

  end
end
