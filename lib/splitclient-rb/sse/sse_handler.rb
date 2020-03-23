# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config, synchronizer, splits_repository, segments_repository)
        @config = config
        @splits_worker = SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, splits_repository)
        @segments_worker = SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, segments_repository)
        @control_worker = SplitIoClient::SSE::Workers::ControlWorker.new(config)
      end

      def start(token_jwt, channels)
        url = "#{@config.sse_host_url}?channels=#{channels}&v=1.1&key=#{token_jwt}"

        @sse_client = SSE::EventSource::Client.new(url, @config) do |client|
          client.on_event do |event|
            process_event(event)
          end

          client.on_error do |error|
            process_error(error)
          end
        end

        block
      end

      def stop
        @sse_client&.close
        @sse_client = nil
      end

      def connected?
        @sse_client&.connected? || false
      end

      def start_workers
        @splits_worker.start
        @segments_worker.start
        @control_worker.start
      end

      def stop_workers
        @splits_worker.stop
        @segments_worker.stop
        @control_worker.stop
      end

      private

      def process_event(event)
        case event.data['type']
        when SSE::EventSource::EventTypes::SPLIT_UPDATE
          split_update_notification(event)
        when SSE::EventSource::EventTypes::SPLIT_KILL
          split_kill_notification(event)
        when SSE::EventSource::EventTypes::SEGMENT_UPDATE
          segment_update_notification(event)
        when SSE::EventSource::EventTypes::CONTROL
          control_notification(event)
        else
          @config.logger.error("Incorrect event type: #{event}")
        end
      end

      def process_error(error)
        @config.logger.error("SSE::EventSource::Client error: #{error}")
      end

      def split_update_notification(event)
        @config.logger.debug("SPLIT UPDATE notification received: #{event}")
        @splits_worker.add_to_queue(event.data['changeNumber'])
      end

      def split_kill_notification(event)
        @config.logger.debug("SPLIT KILL notification received: #{event}")

        change_number = event.data['changeNumber']
        default_treatment = event.data['defaultTreatment']
        split_name = event.data['splitName']

        @splits_worker.kill_split(change_number, split_name, default_treatment)
      end

      def segment_update_notification(event)
        @config.logger.debug("SEGMENT UPDATE notification received: #{event}")
        change_number = event.data['changeNumber']
        segment_name = event.data['segmentName']

        @segments_worker.add_to_queue(change_number, segment_name)
      end

      def control_notification(event)
        @config.logger.debug("CONTROL notification received: #{event}")
      end

      def block
        begin
          timeout = @config.connection_timeout
          Timeout.timeout(timeout) do
            sleep 0.1 until connected?
          end
        rescue Timeout::Error
          @config.logger.error('SSE connection is not ready.')
          @sse_client&.close
        end

        @config.logger.info('SSE connection is ready.')
      end
    end
  end
end
