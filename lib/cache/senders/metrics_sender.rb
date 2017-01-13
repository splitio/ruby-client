module SplitIoClient
  module Cache
    module Senders
      class MetricsSender
        def initialize(metrics_repository, config, api_key)
          @metrics_repository = metrics_repository
          @config = config
          @api_key = api_key
        end

        def call
          return if ENV['SPLITCLIENT_ENV'] == 'test'

          metrics_thread

          if defined?(PhusionPassenger)
            PhusionPassenger.on_event(:starting_worker_process) do |forked|
              metrics_thread if forked
            end
          end
        end

        private

        def metrics_thread
          Thread.new do
            @config.logger.info('Starting metrics service')

            loop do
              post_metrics

              sleep(::Utilities.randomize_interval(@config.metrics_refresh_rate))
            end
          end
        end

        def post_metrics
          metrics_client.post
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def metrics_client
          SplitIoClient::Api::Metrics.new(@api_key, @config, @metrics_repository)
        end
      end
    end
  end
end
