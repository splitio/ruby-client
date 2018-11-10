module SplitIoClient
  class SplitFactory
    include SplitIoClient::Cache::Repositories
    include SplitIoClient::Cache::Stores

    attr_reader :adapter, :client, :manager

    def initialize(api_key, config_hash = {})
      @api_key = api_key
      SplitIoClient.configure(config_hash)

      raise 'Invalid SDK mode' unless valid_mode

      @cache_adapter = SplitIoClient.configuration.cache_adapter

      @splits_repository = SplitsRepository.new(@cache_adapter)
      @segments_repository = SegmentsRepository.new(@cache_adapter)
      @impressions_repository = ImpressionsRepository.new(SplitIoClient.configuration.impressions_adapter)
      @metrics_repository = MetricsRepository.new(SplitIoClient.configuration.metrics_adapter)
      @events_repository = EventsRepository.new(SplitIoClient.configuration.events_adapter)

      @sdk_blocker = SDKBlocker.new(@splits_repository, @segments_repository)
      @adapter = start!

      @client = SplitClient.new(@api_key, @adapter, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository, @events_repository)
      @manager = SplitManager.new(@api_key, @adapter, @splits_repository)

      @sdk_blocker.block if SplitIoClient.configuration.block_until_ready > 0
    end

    def start!
      SplitAdapter.new(@api_key, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository, @events_repository, @sdk_blocker)
    end

    def stop!
      SplitIoClient.configuration.threads.each { |_, t| t.exit }
    end

    def valid_mode
      valid_startup_mode = false
      case SplitIoClient.configuration.mode
      when :consumer
        if SplitIoClient.configuration.cache_adapter.is_a? SplitIoClient::Cache::Adapters::RedisAdapter
          valid_startup_mode = true
        else
          SplitIoClient.configuration.logger.error('Consumer mode cannot be used with Memory adapter. ' \
            'Use Redis adapter instead.')
        end
      when :standalone
        if SplitIoClient.configuration.cache_adapter.is_a? SplitIoClient::Cache::Adapters::MemoryAdapter
          valid_startup_mode = true
        else
          SplitIoClient.configuration.logger.error('Standalone mode cannot be used with Redis adapter. ' \
            'Use Memory adapter instead.')
        end
      when :producer
        SplitIoClient.configuration.logger.error('Producer mode is no longer supported. Use Split Synchronizer. ' \
          'See: https://github.com/splitio/split-synchronizer')
      else
        SplitIoClient.configuration.logger.error('Invalid SDK mode selected. ' \
          "Valid modes are 'standalone with memory adapter' and 'consumer with redis adapter'")
      end

      return valid_startup_mode
    end

    alias resume! start!
  end
end
