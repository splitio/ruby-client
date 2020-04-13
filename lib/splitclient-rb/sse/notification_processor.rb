# frozen_string_literal: true

module SplitIoClient
  module SSE
    class NotificationProcessor
      def initialize(config, splits_worker, segments_worker)
        @config = config
        @splits_worker = splits_worker
        @segments_worker = segments_worker
      end

      def process(incoming_notification)
        case incoming_notification.data['type']
        when SSE::EventSource::EventTypes::SPLIT_UPDATE
          process_split_update(incoming_notification)
        when SSE::EventSource::EventTypes::SPLIT_KILL
          process_split_kill(incoming_notification)
        when SSE::EventSource::EventTypes::SEGMENT_UPDATE
          process_segment_update(incoming_notification)
        else
          @config.logger.error("Incorrect event type: #{event}")
        end
      end

      private

      def process_split_update(notification)
        @config.logger.debug("SPLIT UPDATE notification received: #{notification}")
        @splits_worker.add_to_queue(notification.data['changeNumber'])
      end

      def process_split_kill(notification)
        @config.logger.debug("SPLIT KILL notification received: #{notification}")
        change_number = notification.data['changeNumber']
        default_treatment = notification.data['defaultTreatment']
        split_name = notification.data['splitName']

        @splits_worker.kill_split(change_number, split_name, default_treatment)
      end

      def process_segment_update(notification)
        @config.logger.debug("SEGMENT UPDATE notification received: #{notification}")
        change_number = notification.data['changeNumber']
        segment_name = notification.data['segmentName']

        @segments_worker.add_to_queue(change_number, segment_name)
      end
    end
  end
end
