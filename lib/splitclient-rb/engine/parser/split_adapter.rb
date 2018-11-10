require 'json'
require 'thread'

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
    # @param metrics_repository [MetricsRepository] SplitsRepository instance to store metrics in
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
      sdk_blocker
    )
      @api_key = api_key
      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository
      @events_repository = events_repository
      @metrics = Metrics.new(100, @metrics_repository)
      @sdk_blocker = sdk_blocker

      start_standalone_components unless SplitIoClient.configuration.mode != :standalone
    end

    def start_standalone_components
      split_store
      segment_store
      metrics_sender
      impressions_sender
      events_sender
    end

    # Starts thread which loops constantly and stores splits in the splits_repository of choice
    def split_store
      SplitStore.new(@splits_repository, @api_key, @metrics, @sdk_blocker).call
    end

    # Starts thread which loops constantly and stores segments in the segments_repository of choice
    def segment_store
      SegmentStore.new(@segments_repository, @api_key, @metrics, @sdk_blocker).call
    end

    # Starts thread which loops constantly and sends impressions to the Split API
    def impressions_sender
      ImpressionsSender.new(@impressions_repository, @api_key).call
    end

    # Starts thread which loops constantly and sends metrics to the Split API
    def metrics_sender
      MetricsSender.new(@metrics_repository, @api_key).call
    end

    # Starts thread which loops constantly and sends events to the Split API
    def events_sender
      EventsSender.new(@events_repository, @api_key).call
    end
  end
end
