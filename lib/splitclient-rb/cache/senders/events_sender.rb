# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class EventsSender
        def initialize(events_repository, api_key)
          @events_repository = events_repository
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
          SplitIoClient.configuration.threads[:events_sender] = Thread.new do
            SplitIoClient.configuration.logger.info('Starting events service')

            loop do
              post_events

              sleep(SplitIoClient::Utilities.randomize_interval(SplitIoClient.configuration.events_push_rate))
            end
          end
        end

        def post_events
          SplitIoClient::Api::Events.new(@api_key, @events_repository.clear).post
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end
      end
    end
  end
end
