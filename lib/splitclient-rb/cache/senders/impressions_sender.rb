# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSender
        def initialize(impressions_repository, api_key)
          @impressions_repository = impressions_repository
          @api_key = api_key
        end

        def call
          if SplitIoClient.configuration.disable_impressions
            SplitIoClient.configuration.logger.info('Disabling impressions service by config')
            return
          end

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
          SplitIoClient.configuration.threads[:impressions_sender] = Thread.new do
            begin
              SplitIoClient.configuration.logger.info('Starting impressions service')

              loop do
                post_impressions(false)

                sleep(SplitIoClient::Utilities.randomize_interval(SplitIoClient.configuration.impressions_refresh_rate))
              end
            rescue SplitIoClient::SDKShutdownException
              post_impressions

              SplitIoClient.configuration.logger.info('Posting impressions due to shutdown')
            end
          end
        end

        def post_impressions(fetch_all_impressions = true)
          formatted_impressions = ImpressionsFormatter.new(@impressions_repository)
            .call(fetch_all_impressions)

          impressions_api.post(formatted_impressions)
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end

        def impressions_api
          @impressions_api ||= SplitIoClient::Api::Impressions.new(@api_key)
        end
      end
    end
  end
end
