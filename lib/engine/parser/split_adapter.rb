require 'json'
require 'thread'
require 'faraday/http_cache'
require 'bundler/vendor/net/http/persistent' unless defined?(Net::HTTP)
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

    attr_reader :impressions_producer

    attr_reader :split_cache, :segment_cache

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
      @cache_adapter = @config.cache_adapter
      @split_cache = SplitIoClient::Cache::Split.new(@cache_adapter)
      @segment_cache = SplitIoClient::Cache::Segment.new(@cache_adapter)

      @api_client = Faraday.new do |builder|
        builder.use FaradayMiddleware::Gzip
        builder.adapter :net_http_persistent
      end

      @splits_consumer = create_splits_api_consumer
      @segments_consumer = create_segments_api_consumer
      @metrics_producer = create_metrics_api_producer
      @impressions_producer = create_impressions_api_producer

    end

    #
    # creates a safe thread that will be executing api calls
    # for fetching splits and segments give the execution time
    # provided within the configuration
    #
    # @return [void]
    def create_splits_api_consumer
      SplitIoClient::Cache::Stores::SplitStore.new(@split_cache, @config, @api_key, @metrics).call
    end

    def create_segments_api_consumer
      SplitIoClient::Cache::Stores::SegmentStore.new(@segment_cache, @split_cache, @config, @api_key, @metrics).call
    end

    #
    # helper method to execute a post request to the provided endpoint
    #
    # @param path [string] api endpoint path
    # @param params [object] hash of params that will be added to the request
    #
    # @return [object] response to the request
    def post_api(path, param)
      @api_client.post (@config.events_uri + path) do |req|
        req.headers['Authorization'] = 'Bearer ' + @api_key
        req.headers['Content-Type'] = 'application/json'
        req.headers['SplitSDKVersion'] = SplitIoClient::SplitFactory.sdk_version
        req.headers['SplitSDKMachineName'] = @config.machine_name
        req.headers['SplitSDKMachineIP'] = @config.machine_ip
        req.body = param.to_json
        req.options.timeout = @config.read_timeout
        req.options.open_timeout = @config.connection_timeout
        @config.logger.debug("POST #{@config.events_uri + path} #{req.body}") if @config.debug_enabled
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
    # creates two safe threads that will be executing api calls
    # for posting impressions and metrics given the execution time
    # provided within the configuration
    #

    def create_metrics_api_producer
      Thread.new do
        loop do
          begin
            #post captured metrics
            post_metrics

            random_interval = randomize_interval @config.metrics_refresh_rate
            sleep(random_interval)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end

    def create_impressions_api_producer
      Thread.new do
        loop do
          begin
            #post captured impressions
            post_impressions

            random_interval = randomize_interval @config.impressions_refresh_rate
            sleep(random_interval)
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
        popped_impressions = @impressions.clear
        test_impression_array = []
        popped_impressions.each do |i|
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
            test_impression_array << test_impression
          end
        end

        res = post_api('/testImpressions/bulk', test_impression_array)
        if res.status / 100 != 2
          @config.logger.error("Unexpected status code while posting impressions: #{res.status}")
        else
          @config.logger.info("Impressions reported.")
          @config.logger.debug("#{test_impression_array}")if @config.debug_enabled
        end
      end
    end

    #
    # creates the appropriate json data for the cached metrics values
    # include latencies, counts and gauges
    # and then sends them to the appropriate api endpoint with a valida body format
    #
    # @return [void]
    def post_metrics
      if @metrics.latencies.empty?
        @config.logger.info('No latencies to report.')
      else
        @metrics.latencies.each do |l|
          metrics_time = {}
          metrics_time = {name: l[:operation], latencies: l[:latencies]}
          res = post_api('/metrics/time', metrics_time)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting time metrics: #{res.status}")
          else
            @config.logger.info("Metric time reported.")
            @config.logger.debug("#{metrics_time}") if @config.debug_enabled
          end
        end
      end
      @metrics.latencies.clear

      if @metrics.counts.empty?
        @config.logger.info('No counts to report.')
      else
        @metrics.counts.each do |c|
          metrics_count = {}
          metrics_count = {name: c[:name], delta: c[:delta].sum}
          res = post_api('/metrics/counter', metrics_count)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting count metrics: #{res.status}")
          else
            @config.logger.info("Metric counts reported.")
            @config.logger.debug("#{metrics_count}") if @config.debug_enabled
          end
        end
      end
      @metrics.counts.clear

      if @metrics.gauges.empty?
        @config.logger.info('No gauges to report.')
      else
        @metrics.gauges.each do |g|
          metrics_gauge = {}
          metrics_gauge = {name: g[:name], value: g[:gauge].value}
          res = post_api('/metrics/gauge', metrics_gauge)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting gauge metrics: #{res.status}")
          else
            @config.logger.info("Metric gauge reported.")
            @config.logger.debug("#{metrics_gauge}") if @config.debug_enabled
          end
        end
      end
      @metrics.gauges.clear
    end

    private

    def randomize_interval(interval)
      @random_generator ||=  Random.new
      random_factor = @random_generator.rand(50..100)/100.0
      interval * random_factor
    end
  end
end
