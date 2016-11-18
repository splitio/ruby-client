module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSender
        def initialize(impressions_repository, config, api_key)
          @impressions_repository = impressions_repository
          @config = config
          @api_key = api_key
        end

        def call
          # Disable impressions if @config.impressions_queue_size == -1
          if @config.impressions_queue_size < 0
            @config.logger.info('Disabling impressions service by config')
            return
          end

          if ENV['SPLITCLIENT_ENV'] == 'test'
            post_impressions
          else
            Thread.new do
              @config.logger.info('Starting impressions service')

              loop do
                post_impressions

                sleep(randomize_interval(@config.impressions_refresh_rate))
              end
            end
          end
        end

        private

        def post_impressions
          impressions_client.post
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        def formatted_impressions(raw_impressions = nil)
          ImpressionsFormatter.new(@impressions_repository).call(raw_impressions)
        end

        def impressions_client
          SplitIoClient::Api::Impressions.new(@api_key, @config, formatted_impressions)
        end

        def randomize_interval(interval)
          @random_generator ||=  Random.new
          random_factor = @random_generator.rand(50..100)/100.0
          interval * random_factor
        end
      end
    end
  end
end
