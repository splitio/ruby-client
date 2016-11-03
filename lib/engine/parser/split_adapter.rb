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
    # handler for metrics
    attr_reader :metrics

    #
    # handler for parsed splits
    attr_reader :parsed_splits

    #
    # handeler for parsed segments
    attr_reader :parsed_segments

    attr_reader :impressions_producer

    attr_reader :splits_repository, :segments_repository, :impressions_repository

    #
    # Creates a new split api adapter instance that consumes split api endpoints
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config, splits_repository, segments_repository, impressions_repository, sdk_blocker)
      @api_key = api_key
      @config = config
      @metrics = Metrics.new(100)

      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository

      @sdk_blocker = sdk_blocker

      @api_client = Faraday.new do |builder|
        builder.use FaradayMiddleware::Gzip
        builder.adapter :net_http_persistent
      end

      start_based_on_mode(@config.mode)
    end

    def start_based_on_mode(mode)
      case mode
      when :standalone
        split_store
        segment_store
        metrics_sender
        impressions_sender
      when :consumer
        metrics_sender
        impressions_sender
      when :producer
        split_store
        segment_store

        sleep unless ENV['SPLITCLIENT_ENV'] == 'test'
      end
    end

    #
    # creates a safe thread that will be executing api calls
    # for fetching splits and segments give the execution time
    # provided within the configuration
    #
    # @return [void]
    def split_store
      SplitIoClient::Cache::Stores::SplitStore.new(@splits_repository, @config, @api_key, @metrics, @sdk_blocker).call
    end

    def segment_store
      SplitIoClient::Cache::Stores::SegmentStore.new(@segments_repository, @config, @api_key, @metrics, @sdk_blocker).call
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

    def metrics_sender
      Thread.new do
        loop do
          begin
            post_metrics

            random_interval = randomize_interval @config.metrics_refresh_rate
            sleep(random_interval)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end

    def impressions_sender
      # Disable impressions if @config.impressions_queue_size == -1
      return if @config.impressions_queue_size > 0

      Thread.new do
        loop do
          begin
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
      impressions = impressions_array

      res = post_api('/testImpressions/bulk', impressions)
      if res.status / 100 != 2
        @config.logger.error("Unexpected status code while posting impressions: #{res.status}")
      else
        @config.logger.debug("Impressions reported: #{impressions}") if @config.debug_enabled
      end
    end

    def impressions_array(impressions = nil)
      impressions_data = impressions || @impressions_repository
      popped_impressions = impressions_data.clear
      test_impression_array = []

      if popped_impressions.empty?
        @config.logger.debug('No impressions to report.') if @config.debug_enabled
      else
        popped_impressions.each do |item|
          keys_treatments_seen = []
          filtered_impressions = []
          item_hash = "#{item[:impressions]['key_name']}:#{item[:impressions]['treatment']}"

          next if keys_treatments_seen.include?(item_hash)

          keys_treatments_seen << item_hash
          filtered_impressions << item

          if filtered_impressions.empty?
            @config.logger.debug('No impressions to report post filtering.') if @config.debug_enabled
          else
            key_impressions = filtered_impressions.each_with_object([]) do |impression, memo|
              memo << {
                keyName: impression[:impressions]['key_name'],
                treatment: impression[:impressions]['treatment'],
                time: impression[:impressions]['time']
              }
            end

            test_impression = { testName: item[:feature], keyImpressions: key_impressions }
            test_impression_array << test_impression
          end
        end
      end

      test_impression_array
    end

    #
    # creates the appropriate json data for the cached metrics values
    # include latencies, counts and gauges
    # and then sends them to the appropriate api endpoint with a valida body format
    #
    # @return [void]
    def post_metrics
      if @metrics.latencies.empty?
        @config.logger.debug('No latencies to report.') if @config.debug_enabled
      else
        @metrics.latencies.each do |l|
          metrics_time = {}
          metrics_time = {name: l[:operation], latencies: l[:latencies]}
          res = post_api('/metrics/time', metrics_time)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting time metrics: #{res.status}")
          else
            @config.logger.debug("Metric time reported: #{metrics_time}") if @config.debug_enabled
          end
        end
      end
      @metrics.latencies.clear

      if @metrics.counts.empty?
        @config.logger.debug('No counts to report.') if @config.debug_enabled
      else
        @metrics.counts.each do |c|
          metrics_count = {}
          metrics_count = {name: c[:name], delta: c[:delta].sum}
          res = post_api('/metrics/counter', metrics_count)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting count metrics: #{res.status}")
          else
            @config.logger.debug("Metric counts reported: #{metrics_count}") if @config.debug_enabled
          end
        end
      end
      @metrics.counts.clear

      if @metrics.gauges.empty?
        @config.logger.debug('No gauges to report.') if @config.debug_enabled
      else
        @metrics.gauges.each do |g|
          metrics_gauge = {}
          metrics_gauge = {name: g[:name], value: g[:gauge].value}
          res = post_api('/metrics/gauge', metrics_gauge)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting gauge metrics: #{res.status}")
          else
            @config.logger.debug("Metric gauge reported: #{metrics_gauge}") if @config.debug_enabled
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
