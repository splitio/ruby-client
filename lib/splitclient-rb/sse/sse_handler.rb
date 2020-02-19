# frozen_string_literal: true

module SplitIoClient
  class SSEHandler
    attr_reader :sse_client

    def initialize(config, adapter)
      @config = config
      @adapter = adapter

      start_sse_client unless ENV['SPLITCLIENT_ENV'] == 'test'
    end

    private

    def start_sse_client
      channels = 'mauro-c'
      key = 'SRFfSQ.kY96dQ:A7whBp7b33NkV_gi'
      url = "https://realtime.ably.io/event-stream?channels=#{channels}&v=1.1&key=#{key}"

      @sse_client = SSE::EventSource::Client.new(url, @config) do |client|
        client.on_event do |event|
          puts event
          proccess_event(event)          
        end

        client.on_error do |error|
          puts error
        end
      end
    end

    def proccess_event(event)
      if event.data['type'] == 'SPLIT_UPDATE'
        @adapter.split_fetcher.fetch_splits
      end
    end
  end
end
