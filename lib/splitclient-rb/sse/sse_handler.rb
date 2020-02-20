# frozen_string_literal: true

module SplitIoClient
  class SSEHandler
    attr_reader :sse_client

    def initialize(config, adapter, channels, key, url_host)
      @config = config
      @adapter = adapter
      @channels = channels
      @key = key
      @url_host = url_host

      # TODO: remove environment condition
      @sse_client = start_sse_client unless ENV['SPLITCLIENT_ENV'] == 'test'
    end

    private

    def start_sse_client
      url = "#{@url_host}/event-stream?channels=#{@channels}&v=1.1&key=#{@key}"

      sse_client = SSE::EventSource::Client.new(url, @config) do |client|
        client.on_event do |event|
          puts event
          process_event(event)
        end

        client.on_error do |error|
          puts error
        end
      end

      sse_client
    end

    def process_event(event)
      case event.data['type']
      when EventTypes::SPLIT_UPDATE
        puts 'split update'
        # @adapter.split_fetcher.fetch_splits
      when EventTypes::SPLIT_KILL
        puts 'split kill'
      when EventTypes::SEGMENT_UPDATE
        puts 'segment update'
      when EventTypes::CONTROL
        puts 'control'
      else
        puts 'ERROR'
      end
    end
  end
end
