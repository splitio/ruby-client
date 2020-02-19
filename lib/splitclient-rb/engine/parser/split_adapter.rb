require 'json'
require 'thread'

include SplitIoClient::Cache::Fetchers
include SplitIoClient::Cache::Stores
include SplitIoClient::Cache::Senders

module SplitIoClient
  #
  # acts as an api adapater to connect to split endpoints
  # uses a configuration object that can be modified when creating the client instance
  # also, uses safe threads to execute fetches and post give the time execution values from the config
  #
  class SplitAdapter < NoMethodError
    attr_reader :splits_repository, :segments_repository, :impressions_repository, :metrics

    #
    # Creates a new split api adapter instance that consumes split api endpoints
    #
    # @param api_key [String] the API key for your split account
    # @param splits_repository [SplitsRepository] SplitsRepository instance to store splits in
    # @param segments_repository [SegmentsRepository] SegmentsRepository instance to store segments in
    # @param impressions_repository [ImpressionsRepository] ImpressionsRepository instance to store impressions in
    # @param metrics_repository [MetricsRepository] MetricsRepository instance to store metrics in
    # @param sdk_blocker [SDKBlocker] SDKBlocker instance which blocks splits_repository/segments_repository
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(
      api_key,
      splits_repository,
      segments_repository,
      impressions_repository,
      metrics_repository,
      events_repository,
      sdk_blocker,
      config
    )
      @api_key = api_key
      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository
      @events_repository = events_repository
      @metrics = Metrics.new(100, @metrics_repository)
      @sdk_blocker = sdk_blocker
      @config = config

      start_localhost_components if @config.localhost_mode

      start_standalone_components if @config.standalone? && !@config.localhost_mode
    end

    def start_standalone_components
      split_fetch
      segment_fetch
      metrics_sender
      impressions_sender
      events_sender
    end

    def start_localhost_components
      localhost_split_store
      localhost_repo_cleaner
    end

    # Starts thread which loops constantly and retrieves splits from a file source
    def localhost_split_store
      LocalhostSplitStore.new(@splits_repository, @config, @sdk_blocker).call
    end

    # Starts thread which loops constantly and cleans up repositories to avoid memory issues in localhost mode
    def localhost_repo_cleaner
      LocalhostRepoCleaner.new(@impressions_repository, @metrics_repository, @events_repository, @config).call
    end

    # Starts thread which loops constantly and stores splits in the splits_repository of choice
    def split_fetch
      SplitFetcher.new(@splits_repository, @api_key, @metrics, @config, @sdk_blocker).call
    end

    # Starts thread which loops constantly and stores segments in the segments_repository of choice
    def segment_fetch
      SegmentFetcher.new(@segments_repository, @api_key, @metrics, @config, @sdk_blocker).call
    end

    # Starts thread which loops constantly and sends impressions to the Split API
    def impressions_sender
      ImpressionsSender.new(@impressions_repository, @api_key, @config).call
    end

    # Starts thread which loops constantly and sends metrics to the Split API
    def metrics_sender
      MetricsSender.new(@metrics_repository, @api_key, @config).call
    end

    # Starts thread which loops constantly and sends events to the Split API
    def events_sender
      EventsSender.new(@events_repository, @config).call
    end
  end
end
