# frozen_string_literal: true
require 'byebug'

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(synchronizer, config, splits_repository)
          @synchronizer = synchronizer
          @config = config
          @splits_repository = splits_repository
          @queue = Queue.new
          @running = Concurrent::AtomicBoolean.new(false)
        end

        def start
          if @running.value
            @config.logger.debug('feature_flags_worker already running.')
            return
          end

          @running.make_true
          perform_thread
        end

        def stop
          unless @running.value
            @config.logger.debug('feature_flags_worker not running.')
            return
          end

          @running.make_false
          SplitIoClient::Helpers::ThreadHelper.stop(:split_update_worker, @config)
        end

        def split_update(notification)
#          byebug
          if @splits_repository.get_change_number() == notification.data['pcn']
            begin
              @new_split = JSON.parse(SplitIoClient::Helpers::DecryptionHelper.get_encoded_definition(notification.data['c'], notification.data['d']), symbolize_names: true)
              @splits_repository.add_split(@new_split)
              @splits_repository.set_change_number(notification.data['changeNumber'])
              return
            rescue Exception => e
              @config.logger.debug("Failed to update Split: #{e.inspect}") if @config.debug_enabled
            end
          end
          @synchronizer.fetch_splits(notification.data['changeNumber'])
        end

        def add_to_queue(notification)
          @config.logger.debug("feature_flags_worker add to queue #{notification.data['changeNumber']}")
          @queue.push(notification)
        end

        def kill_split(notification)
          return if @splits_repository.get_change_number.to_i > notification.data['changeNumber']

          @config.logger.debug("feature_flags_worker kill #{notification.data['splitName']}, #{notification.data['changeNumber']}")
          @splits_repository.kill(notification.data['changeNumber'], notification.data['splitName'], notification.data['defaultTreatment'])
          @synchronizer.fetch_splits(notification.data['changeNumber'])
        end

        private

        def perform
          while (notification = @queue.pop)
            @config.logger.debug("feature_flags_worker change_number dequeue #{notification.data['changeNumber']}")
            case notification.data['type']
            when SSE::EventSource::EventTypes::SPLIT_UPDATE
              split_update(notification)
            when SSE::EventSource::EventTypes::SPLIT_KILL
              kill_split(notification)
            end
          end
        end

        def perform_thread
          @config.threads[:split_update_worker] = Thread.new do
            @config.logger.debug('starting feature_flags_worker ...') if @config.debug_enabled
            perform
          end
        end
      end
    end
  end
end
