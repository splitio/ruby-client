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
    def initialize(api_key, config, splits_repository, segments_repository, impressions_repository, metrics_repository, sdk_blocker)
      @api_key = api_key
      @config = config

      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository

      @metrics = Metrics.new(100, @config, @metrics_repository)

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
        # Do nothing in background
      when :producer
        split_store
        segment_store
        impressions_sender
        metrics_sender

        sleep unless ENV['SPLITCLIENT_ENV'] == 'test'
      end
    end

    # Starts thread which loops constantly and stores splits in the splits_repository of choice
    def split_store
      SplitIoClient::Cache::Stores::SplitStore.new(@splits_repository, @config, @api_key, @metrics, @sdk_blocker).call
    end

    # Starts thread which loops constantly and stores segments in the segments_repository of choice
    def segment_store
      SplitIoClient::Cache::Stores::SegmentStore.new(@segments_repository, @config, @api_key, @metrics, @sdk_blocker).call
    end

    # Starts thread which loops constantly and sends impressions to the Split API
    def impressions_sender
      SplitIoClient::Cache::Senders::ImpressionsSender.new(@impressions_repository, @config, @api_key).call
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

        if @config.transport_debug_enabled
          @config.logger.debug("POST #{@config.events_uri + path} #{req.body}")
        elsif @config.debug_enabled
          @config.logger.debug("POST #{@config.events_uri + path}")
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
    # creates two safe threads that will be executing api calls
    # for posting impressions and metrics given the execution time
    # provided within the configuration
    #

    def metrics_sender
      # TODO: Send metrics in main thread for test ENV
      return if ENV['SPLITCLIENT_ENV'] == 'test'

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

    #
    # creates the appropriate json data for the cached metrics values
    # include latencies, counts and gauges
    # and then sends them to the appropriate api endpoint with a valida body format
    #
    # @return [void]
    def post_metrics
      if @metrics_repository.latencies.empty?
        @config.logger.debug('No latencies to report.') if @config.debug_enabled
      else
        @metrics_repository.latencies.each do |name, latencies|
          metrics_time = { name: name, latencies: latencies }
          res = post_api('/metrics/time', metrics_time)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting time metrics: #{res.status}")
          else
            @config.logger.debug("Metric time reported: #{metrics_time.size}") if @config.debug_enabled
          end
        end
      end
      @metrics_repository.clear_latencies

      if @metrics_repository.counts.empty?
        @config.logger.debug('No counts to report.') if @config.debug_enabled
      else
        @metrics_repository.counts.each do |name, count|
          metrics_count = { name: name, delta: count }
          res = post_api('/metrics/counter', metrics_count)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting count metrics: #{res.status}")
          else
            @config.logger.debug("Metric counts reported: #{metrics_count.size}") if @config.debug_enabled
          end
        end
      end
      @metrics_repository.clear_counts
    end

    private

    def randomize_interval(interval)
      @random_generator ||=  Random.new
      random_factor = @random_generator.rand(50..100)/100.0
      interval * random_factor
    end
  end
end
