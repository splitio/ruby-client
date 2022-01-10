# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsCountSender
        COUNTER_REFRESH_RATE_SECONDS = 1800

        def initialize(config, impression_counter, impressions_api)
          @config = config
          @impression_counter = impression_counter
          @impressions_api = impressions_api
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
                post_impressions_count

                sleep(COUNTER_REFRESH_RATE_SECONDS)
              end
            rescue SplitIoClient::SDKShutdownException
              post_impressions_count

              @config.logger.info('Posting impressions count due to shutdown')
            end
          end
        end

        def post_impressions_count
          @impressions_api.post_count(formatter(@impression_counter.pop_all))
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def formatter(counts)
          return if counts.empty?

          formated_counts = {pf: []}

          counts.each do |key, value|              
            key_splited = key.split('::')
            
            formated_counts[:pf] << {
              f: key_splited[0].to_s, # feature name
              m: key_splited[1].to_i, # time frame
              rc: value # count
            }
          end

          formated_counts
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
