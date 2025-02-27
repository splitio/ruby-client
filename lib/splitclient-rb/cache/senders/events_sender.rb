# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class EventsSender
        def initialize(events_repository, config)
          @events_repository = events_repository
          @config = config
        end

        def call          
          events_thread
        end

        private

        def events_thread
          @config.threads[:events_sender] = Thread.new do
            begin
              @config.logger.info('Starting events service')

              loop do
                post_events

                sleep(SplitIoClient::Utilities.randomize_interval(@config.events_push_rate))
              end
            rescue SplitIoClient::SDKShutdownException
              post_events

              @config.logger.info('Posting events due to shutdown')
            end
          end
        end

        def post_events
          @events_repository.post_events
        end
      end
    end
  end
end
