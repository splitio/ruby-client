# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class LocalhostRepoCleaner
        def initialize(impressions_repository, metrics_repository, events_repository, config)
          @impressions_repository = impressions_repository
          @metrics_repository = metrics_repository
          @events_repository = events_repository
          @config = config
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            clear_repositories
          else
            cleaner_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                cleaner_thread if forked
              end
            end
          end
        end

        private

        def cleaner_thread
          @config.threads[:repo_cleaner] = Thread.new do
            @config.logger.info('Starting repositories cleanup service')
            loop do
              clear_repositories

              sleep(SplitIoClient::Utilities.randomize_interval(@config.features_refresh_rate))
            end
          end
        end

        def clear_repositories
          @impressions_repository.clear
          @metrics_repository.clear
          @events_repository.clear
        end
      end
    end
  end
end
