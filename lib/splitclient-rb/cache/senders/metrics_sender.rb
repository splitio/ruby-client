# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class MetricsSender
        def initialize(metrics_repository, api_key)
          @metrics_repository = metrics_repository
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
          SplitIoClient.configuration.threads[:metrics_sender] = Thread.new do
            SplitIoClient.configuration.logger.info('Starting metrics service')

            loop do
              post_metrics

              sleep(SplitIoClient::Utilities.randomize_interval(SplitIoClient.configuration.metrics_refresh_rate))
            end
          end
        end

        def post_metrics
          metrics_api.post
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end

        def metrics_api
          @metrics_api ||= SplitIoClient::Api::Metrics.new(@api_key, @metrics_repository)
        end
      end
    end
  end
end
