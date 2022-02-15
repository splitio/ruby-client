module SplitIoClient
  class SplitFactory
    ROOT_PROCESS_ID = Process.pid
    SINGLETON_WARN = 'We recommend keeping only one instance of the factory at all times (Singleton pattern) and reusing it throughout your application'
    LOCALHOST_API_KEY = 'localhost'

    include SplitIoClient::Cache::Repositories
    include SplitIoClient::Cache::Stores
    include SplitIoClient::Cache::Senders
    include SplitIoClient::Cache::Fetchers

    attr_reader :adapter, :client, :manager, :config

    def initialize(api_key, config_hash = {})
      at_exit do
        unless ENV['SPLITCLIENT_ENV'] == 'test'
          if (Process.pid == ROOT_PROCESS_ID)
            @config.logger.info('Split SDK shutdown started...')
            @client.destroy if @client
            stop!
            @config.logger.info('Split SDK shutdown complete')
          end
        end
      end

      @api_key = api_key
      @config = SplitConfig.new(config_hash.merge(localhost_mode: @api_key == LOCALHOST_API_KEY ))

      raise 'Invalid SDK mode' unless valid_mode

      validate_api_key

      register_factory

      build_telemetry_components
      build_repositories
      build_impressions_components
      build_telemetry_synchronizer

      @status_manager = Engine::StatusManager.new(@config)

      start!

      @client = SplitClient.new(@api_key, repositories, @status_manager, @config, @impressions_manager, @evaluation_producer)
      @manager = SplitManager.new(@splits_repository, @status_manager, @config)
    end

    def start!
      return start_localhost_components if @config.localhost_mode

      if @config.consumer?
        @status_manager.ready!
        @telemetry_synchronizer.synchronize_config
        return
      end
      
      build_fetchers
      build_synchronizer
      build_streaming_components
      build_sync_manager

      @sync_manager.start
    end

    def stop!
      @config.threads.each { |_, t| t.exit }
    end

    def register_factory
      SplitIoClient.load_factory_registry

      number_of_factories = SplitIoClient.split_factory_registry.number_of_factories_for(@api_key)

      if(number_of_factories > 0)
        @config.logger.warn("Factory instantiation: You already have #{number_of_factories} factories with this API Key. #{SINGLETON_WARN}")
      elsif(SplitIoClient.split_factory_registry.other_factories)
        @config.logger.warn('Factory instantiation: You already have an instance of the Split factory.' \
          " Make sure you definitely want this additional instance. #{SINGLETON_WARN}")
      end

      SplitIoClient.split_factory_registry.add(@api_key)
    end

    def valid_mode
      valid_startup_mode = false
      case @config.mode
      when :consumer
        if @config.cache_adapter.is_a? SplitIoClient::Cache::Adapters::RedisAdapter
          if !@config.localhost_mode
            valid_startup_mode = true
          else
            @config.logger.error('Localhost mode cannot be used with Redis. ' \
              'Use standalone mode and Memory adapter instead.')
          end
        else
          @config.logger.error('Consumer mode cannot be used with Memory adapter. ' \
            'Use Redis adapter instead.')
        end
      when :standalone
        if @config.cache_adapter.is_a? SplitIoClient::Cache::Adapters::MemoryAdapter
          valid_startup_mode = true
        else
          @config.logger.error('Standalone mode cannot be used with Redis adapter. ' \
            'Use Memory adapter instead.')
        end
      when :producer
        @config.logger.error('Producer mode is no longer supported. Use Split Synchronizer. ' \
          'See: https://github.com/splitio/split-synchronizer')
      else
        @config.logger.error('Invalid SDK mode selected. ' \
          "Valid modes are 'standalone with memory adapter' and 'consumer with redis adapter'")
      end

      valid_startup_mode
    end

    alias resume! start!

    private

    def validate_api_key
      if(@api_key.nil?)
        @config.logger.error('Factory Instantiation: you passed a nil api_key, api_key must be a non-empty String')
        @config.valid_mode =  false
      elsif (@api_key.empty?)
        @config.logger.error('Factory Instantiation: you passed and empty api_key, api_key must be a non-empty String')
        @config.valid_mode =  false
      end
    end

    def repositories
      { 
        splits: @splits_repository,
        segments: @segments_repository,
        impressions: @impressions_repository,
        events: @events_repository,
      }
    end

    def start_localhost_components
      LocalhostSplitStore.new(@splits_repository, @config, @status_manager).call

      # Starts thread which loops constantly and cleans up repositories to avoid memory issues in localhost mode
      LocalhostRepoCleaner.new(@impressions_repository, @events_repository, @config).call
    end

    def build_telemetry_components
      @evaluation_consumer = Telemetry::EvaluationConsumer.new(@config)
      @evaluation_producer = Telemetry::EvaluationProducer.new(@config)

      @init_consumer = Telemetry::InitConsumer.new(@config)
      @init_producer = Telemetry::InitProducer.new(@config)

      @runtime_consumer = Telemetry::RuntimeConsumer.new(@config)
      @runtime_producer = Telemetry::RuntimeProducer.new(@config)

      @telemetry_consumers = { init: @init_consumer, evaluation: @evaluation_consumer, runtime: @runtime_consumer }
    end

    def build_fetchers
      @split_fetcher = SplitFetcher.new(@splits_repository, @api_key, @config, @runtime_producer)
      @segment_fetcher = SegmentFetcher.new(@segments_repository, @api_key, @config, @runtime_producer)
    end

    def build_synchronizer
      params = {
        split_fetcher: @split_fetcher,
        segment_fetcher: @segment_fetcher,
        imp_counter: @impression_counter,
        telemetry_runtime_producer: @runtime_producer,
        telemetry_synchronizer: @telemetry_synchronizer
      }

      @synchronizer = Engine::Synchronizer.new(repositories, @api_key, @config, params)
    end

    def build_streaming_components      
      splits_worker = SSE::Workers::SplitsWorker.new(@synchronizer, @config, @splits_repository)
      segments_worker = SSE::Workers::SegmentsWorker.new(@synchronizer, @config, @segments_repository)
      notification_manager_keeper = SSE::NotificationManagerKeeper.new(@config, @runtime_producer)
      notification_processor = SSE::NotificationProcessor.new(@config, splits_worker, segments_worker)
      event_parser = SSE::EventSource::EventParser.new(config)
      @push_status_queue = Queue.new
      sse_client = SSE::EventSource::Client.new(@config, @api_key, @runtime_producer, event_parser, notification_manager_keeper, notification_processor, @push_status_queue)
      @sse_handler = SSE::SSEHandler.new(@config, splits_worker, segments_worker, sse_client)
      @push_manager = Engine::PushManager.new(@config, @sse_handler, @api_key, @runtime_producer)
    end

    def build_sync_manager
      @sync_manager = Engine::SyncManager.new(@config, @synchronizer, @runtime_producer, @telemetry_synchronizer, @status_manager, @sse_handler, @push_manager, @push_status_queue)
    end

    def build_repositories
      @splits_repository = SplitsRepository.new(@config)
      @segments_repository = SegmentsRepository.new(@config)
      @impressions_repository = ImpressionsRepository.new(@config)
      @events_repository = EventsRepository.new(@config, @api_key, @runtime_producer)
    end

    def build_telemetry_synchronizer
      telemetry_api = Api::TelemetryApi.new(@config, @api_key, @runtime_producer)
      @telemetry_synchronizer = Telemetry::Synchronizer.new(@config, @telemetry_consumers, @init_producer, repositories, telemetry_api)
    end

    def build_impressions_components
      @impression_counter = Engine::Common::ImpressionCounter.new
      @impressions_manager = Engine::Common::ImpressionManager.new(@config, @impressions_repository, @impression_counter, @runtime_producer)
    end
  end
end
