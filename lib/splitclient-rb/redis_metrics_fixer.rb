# frozen_string_literal: true

module SplitIoClient
  class RedisMetricsFixer
    def initialize(metrics_repository)
      @metrics_repository = metrics_repository
    end

    def call
      return if ENV['SPLITCLIENT_ENV'] == 'test' || SplitIoClient.configuration.mode == :standalone

      fixer_thread

      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          fixer_thread if forked
        end
      end
    end

    private

    def fixer_thread
      Thread.new do
        begin
          SplitIoClient.configuration.logger.info('Starting redis metrics fixer')

          @metrics_repository.fix_latencies
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
