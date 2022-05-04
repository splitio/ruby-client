# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSender
        def initialize(impressions_repository, config, impressions_api)
          @impressions_repository = impressions_repository
          @config = config
          @impressions_api = impressions_api
        end

        def call
          impressions_thread
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
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def impressions_api
          @impressions_api
        end
      end
    end
  end
end
