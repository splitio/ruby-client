# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(synchronizer, config, feature_flags_repository, telemetry_runtime_producer, segment_fetcher)
          @synchronizer = synchronizer
          @config = config
          @feature_flags_repository = feature_flags_repository
          @queue = Queue.new
          @running = Concurrent::AtomicBoolean.new(false)
          @telemetry_runtime_producer = telemetry_runtime_producer
          @segment_fetcher = segment_fetcher
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
          Helpers::ThreadHelper.stop(:split_update_worker, @config)
        end

        def add_to_queue(notification)
          @config.logger.debug("feature_flags_worker add to queue #{notification.data['changeNumber']}")
          @queue.push(notification)
        end

        private

        def perform_thread
          @config.threads[:split_update_worker] = Thread.new do
            @config.logger.debug('starting feature_flags_worker ...') if @config.debug_enabled
            perform
          end
        end

        def perform
          while (notification = @queue.pop)
            @config.logger.debug("feature_flags_worker change_number dequeue #{notification.data['changeNumber']}")
            case notification.data['type']
            when SSE::EventSource::EventTypes::SPLIT_UPDATE
              success = update_feature_flag(notification)
              @synchronizer.fetch_splits(notification.data['changeNumber']) unless success
            when SSE::EventSource::EventTypes::SPLIT_KILL
              kill_feature_flag(notification)
            end
          end
        end

        def update_feature_flag(notification)
          return true if @feature_flags_repository.get_change_number.to_i >= notification.data['changeNumber']
          return false unless !notification.data['d'].nil? && @feature_flags_repository.get_change_number == notification.data['pcn']

          new_split = return_split_from_json(notification)
          if Engine::Models::Split.archived?(new_split)
            @feature_flags_repository.remove_split(new_split)
          else
            @feature_flags_repository.add_split(new_split)

            fetch_segments_if_not_exists(new_split)
          end

          @feature_flags_repository.set_change_number(notification.data['changeNumber'])
          @telemetry_runtime_producer.record_updates_from_sse(Telemetry::Domain::Constants::SPLITS)

          true
        rescue StandardError => e
          @config.logger.debug("Failed to update Split: #{e.inspect}") if @config.debug_enabled

          false
        end

        def kill_feature_flag(notification)
          return if @feature_flags_repository.get_change_number.to_i > notification.data['changeNumber']

          @config.logger.debug("feature_flags_worker kill #{notification.data['splitName']}, #{notification.data['changeNumber']}")
          @feature_flags_repository.kill(
            notification.data['changeNumber'],
            notification.data['splitName'],
            notification.data['defaultTreatment']
          )
          @synchronizer.fetch_splits(notification.data['changeNumber'])
        end

        def return_split_from_json(notification)
          split_json = Helpers::DecryptionHelper.get_encoded_definition(notification.data['c'], notification.data['d'])

          JSON.parse(split_json, symbolize_names: true)
        end

        def fetch_segments_if_not_exists(feature_flag)
          segment_names = Helpers::Util.segment_names_by_feature_flag(feature_flag)
          return if segment_names.nil?

          @feature_flags_repository.set_segment_names(segment_names)
          @segment_fetcher.fetch_segments_if_not_exists(segment_names)
        end
      end
    end
  end
end
