# frozen_string_literal: true

module SplitIoClient
  class SSEHandler
    attr_reader :sse_client

    def initialize(config, channels, key, url_host, split_update_worker, segment_update_worker)
      @config = config
      @channels = channels
      @key = key
      @url_host = url_host
      @split_update_worker = split_update_worker
      @segment_update_worker = segment_update_worker

      # TODO: remove environment condition
      @sse_client = start_sse_client unless ENV['SPLITCLIENT_ENV'] == 'test'
    end

    private

    def start_sse_client
      url = "#{@url_host}/event-stream?channels=#{@channels}&v=1.1&key=#{@key}"

      sse_client = SSE::EventSource::Client.new(url, @config) do |client|
        client.on_event do |event|
          process_event(event)
        end

        client.on_error do |error|
          process_error(error)
        end
      end

      sse_client
    end

    def process_event(event)
      case event.data['type']
      when EventTypes::SPLIT_UPDATE
        @config.logger.debug("SPLIT UPDATE notification received: #{event}")
        @split_update_worker.add_to_adapter(event.data['changeNumber'])
      when EventTypes::SPLIT_KILL
        @config.logger.debug("SPLIT KILL notification received: #{event}")
        @split_update_worker.add_to_adapter(event.data['changeNumber'])
      when EventTypes::SEGMENT_UPDATE
        @config.logger.debug("SEGMENT UPDATE notification received: #{event}")
        change_number = event.data['changeNumber']
        segment_name = event.data['segmentName']
        @segment_update_worker.add_to_adapter(change_number, segment_name)
      when EventTypes::CONTROL
        @config.logger.debug("CONTROL notification received: #{event}")
      else
        puts 'NO LE GUSTO NINGUN TIPO'
      end
    end

    def process_error(error)
      puts error
    end
  end
end
