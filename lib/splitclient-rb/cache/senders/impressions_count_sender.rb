# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsCountSender
        def initialize(config, impression_counter, impressions_sender_adapter)
          @config = config
          @impression_counter = impression_counter
          @impressions_sender_adapter = impressions_sender_adapter
        end

        def call
          impressions_count_thread
        end

        private

        def impressions_count_thread
          @config.threads[:impressions_count_sender] = Thread.new do
            begin
              @config.logger.info('Starting impressions count service')

              loop do
                sleep(@config.counter_refresh_rate)

                post_impressions_count                
              end
            rescue SplitIoClient::SDKShutdownException
              post_impressions_count

              @config.logger.info('Posting impressions count due to shutdown')
            end
          end
        end

        def post_impressions_count
          @impressions_sender_adapter.record_impressions_count(@impression_counter.pop_all)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
