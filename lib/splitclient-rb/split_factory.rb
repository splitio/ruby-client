module SplitIoClient
  class SplitFactory
    include SplitIoClient::Cache::Repositories
    include SplitIoClient::Cache::Stores

    attr_reader :adapter, :client, :manager

    def initialize(api_key, config_hash = {})
      @api_key = api_key
      @config = SplitConfig.new(config_hash)

      @cache_adapter = @config.cache_adapter

      @splits_repository = SplitsRepository.new(@cache_adapter, @config)
      @segments_repository = SegmentsRepository.new(@cache_adapter, @config)
      @impressions_repository = ImpressionsRepository.new(@config.impressions_adapter, @config)
      @metrics_repository = MetricsRepository.new(@config.metrics_adapter, @config)

      @sdk_blocker = SDKBlocker.new(@config, @splits_repository, @segments_repository)
      @adapter = start!

      @client = SplitClient.new(@api_key, @config, @adapter, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository)
      @manager = SplitManager.new(@api_key, @config, @adapter, @splits_repository)

      @sdk_blocker.block if @config.block_until_ready > 0
    end

    def start!
      SplitAdapter.new(@api_key, @config, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository, @sdk_blocker)
    end

    alias resume! start!
  end
end
