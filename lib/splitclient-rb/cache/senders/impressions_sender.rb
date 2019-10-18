# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSender
        def initialize(impressions_repository, api_key, config)
          @impressions_repository = impressions_repository
          @api_key = api_key
          @config = config
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            post_impressions
          else
            impressions_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                impressions_thread if forked
              end
            end
          end
        end

        private

        def impressions_thread
          @config.threads[:impressions_sender] = Thread.new do
            begin
              @config.logger.info('Starting impressions service')

              loop do
                post_impressions(false)

                sleep(SplitIoClient::Utilities.randomize_interval(@config.impressions_refresh_rate))
              end
            rescue SplitIoClient::SDKShutdownException
              post_impressions

              @config.logger.info('Posting impressions due to shutdown')
            end
          end
        end

        def post_impressions(fetch_all_impressions = true)
          formatted_impressions = ImpressionsFormatter.new(@impressions_repository)
            .call(fetch_all_impressions)

          impressions_api.post(formatted_impressions)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def impressions_api
          @impressions_api ||= SplitIoClient::Api::Impressions.new(@api_key, @config)
        end
      end
    end
  end
end
