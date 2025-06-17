# frozen_string_literal: true

module SplitIoClient
  module SSE
    module Workers
      class SplitsWorker
        def initialize(synchronizer, config, feature_flags_repository, telemetry_runtime_producer,
                       segment_fetcher, rule_based_segment_repository)
          @synchronizer = synchronizer
          @config = config
          @feature_flags_repository = feature_flags_repository
          @queue = Queue.new
          @running = Concurrent::AtomicBoolean.new(false)
          @telemetry_runtime_producer = telemetry_runtime_producer
          @segment_fetcher = segment_fetcher
          @rule_based_segment_repository = rule_based_segment_repository
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
              @synchronizer.fetch_splits(notification.data['changeNumber'], 0) unless success
            when SSE::EventSource::EventTypes::RB_SEGMENT_UPDATE
              success = update_rule_based_segment(notification)
              @synchronizer.fetch_splits(0, notification.data['changeNumber']) unless success
            when SSE::EventSource::EventTypes::SPLIT_KILL
              kill_feature_flag(notification)
            end
          end
        end

        def update_feature_flag(notification)
          return true if @feature_flags_repository.get_change_number.to_i >= notification.data['changeNumber']
          return false unless !notification.data['d'].nil? && @feature_flags_repository.get_change_number == notification.data['pcn']

          new_split = update_feature_flag_repository(notification)
          fetch_segments_if_not_exists(Helpers::Util.segment_names_by_object(new_split, 'IN_SEGMENT'), @feature_flags_repository)
          if fetch_rule_based_segments_if_not_exists(Helpers::Util.segment_names_by_object(new_split, 'IN_RULE_BASED_SEGMENT'),
                                                     notification.data['changeNumber'])
            return true
          end

          @telemetry_runtime_producer.record_updates_from_sse(Telemetry::Domain::Constants::SPLITS)

          true
        rescue StandardError => e
          @config.logger.debug("Failed to update Split: #{e.inspect}") if @config.debug_enabled

          false
        end

        def update_feature_flag_repository(notification)
          new_split = return_object_from_json(notification)
          SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(@feature_flags_repository, [new_split],
                                                                                  notification.data['changeNumber'], @config, false)
          new_split
        end

        def update_rule_based_segment(notification)
          return true if @rule_based_segment_repository.get_change_number.to_i >= notification.data['changeNumber']
          return false unless !notification.data['d'].nil? &&
                              @rule_based_segment_repository.get_change_number == notification.data['pcn']

          new_rb_segment = return_object_from_json(notification)
          SplitIoClient::Helpers::RepositoryHelper.update_rule_based_segment_repository(@rule_based_segment_repository,
                                                                                        [new_rb_segment],
                                                                                        notification.data['changeNumber'], @config)
          fetch_segments_if_not_exists(Helpers::Util.segment_names_in_rb_segment(new_rb_segment, 'IN_SEGMENT'),
                                       @rule_based_segment_repository)

          # @telemetry_runtime_producer.record_updates_from_sse(Telemetry::Domain::Constants::SPLITS)

          true
        rescue StandardError => e
          @config.logger.debug("Failed to update Split: #{e.inspect}") if @config.debug_enabled

          false
        end

        def kill_feature_flag(notification)
          return if @feature_flags_repository.get_change_number.to_i > notification.data['changeNumber']

          @config.logger.debug("feature_flags_worker kill #{notification.data['splitName']}, #{notification.data['changeNumber']}")
          @feature_flags_repository.kill(notification.data['changeNumber'],
                                         notification.data['splitName'],
                                         notification.data['defaultTreatment'])
          @synchronizer.fetch_splits(notification.data['changeNumber'], 0)
        end

        def return_object_from_json(notification)
          object_json = Helpers::DecryptionHelper.get_encoded_definition(notification.data['c'], notification.data['d'])
          JSON.parse(object_json, symbolize_names: true)
        end

        def fetch_segments_if_not_exists(segment_names, object_repository)
          return if segment_names.nil?

          object_repository.set_segment_names(segment_names)
          @segment_fetcher.fetch_segments_if_not_exists(segment_names)
        end

        def fetch_rule_based_segments_if_not_exists(segment_names, change_number)
          return false if segment_names.nil? || segment_names.empty? || @rule_based_segment_repository.contains?(segment_names.to_a)

          @synchronizer.fetch_splits(0, change_number)

          true
        end
      end
    end
  end
end
