module SplitIoClient
  module Cache
    module Senders
      class EventsSender
        def initialize(events_repository, config, api_key)
          @events_repository = events_repository
          @config = config
          @api_key = api_key
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            post_events
          else
            events_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                events_thread if forked
              end
            end
          end
        end

        private

        def events_thread
          @config.threads[:events_sender] = Thread.new do
            @config.logger.info('Starting events service')

            loop do
              post_events

              sleep(SplitIoClient::Utilities.randomize_interval(@config.events_push_rate))
            end
          end
        end

        def post_events
          SplitIoClient::Api::Events.new(@api_key, @config, @events_repository.clear).post
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
