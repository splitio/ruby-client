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
                post_impressions

                sleep(SplitIoClient::Utilities.randomize_interval(SplitIoClient.configuration.impressions_refresh_rate))
              end
            rescue SplitIoClient::ImpressionShutdownException
              post_impressions

              @impressions_repository.clear
            end
          end
        end

        def post_impressions
          impressions_client.post
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end

        def formatted_impressions(raw_impressions = nil)
          ImpressionsFormatter.new(@impressions_repository).call(raw_impressions)
        end

        def impressions_client
          SplitIoClient::Api::Impressions.new(@api_key, formatted_impressions)
        end
      end
    end
  end
end
