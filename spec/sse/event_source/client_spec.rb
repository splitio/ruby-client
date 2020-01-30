# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SSE::EventSource::Client do 
  subject { SSE::EventSource::Client }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:simple_event_1_text) { <<-EOT
event: message
data: { "channel": "channel-test", "id": 123, "name": "name-test", "data": "data-test"  }
id: a

EOT
  }

  it "no se que voy a testear" do
    channels = 'channel-test'
    key = 'key-test'
    
    with_server do |server|
      server.setup_response("/") do |req,res|
        send_stream_content(res, simple_event_1_text, keep_open: false)
      end

      server.setup_response("/") do |req,res|
        send_stream_content(res, simple_event_1_text, keep_open: false)
      end
      event_queue = Queue.new
      client = subject.new(server.base_uri, config, read_timeout: 50) do |c|        
        c.on_event do |event| 
          event_queue << event
        end
      end
      
      with_client(client) do |client|
        event_result = event_queue.pop
        expect(event_result.type).to eq("message")
        expect(event_result.name).to eq("name-test")
        expect(event_result.channel).to eq("channel-test")
        expect(event_result.data).to eq("data-test")
        expect(event_result.id).to eq(123)
      end
    end
  end

  def with_client(client)
    begin
      yield client
    ensure
      client.close
    end
  end

  def send_stream_content(res, content, keep_open:)
    res.content_type = "text/event-stream"
    res.status = 200
    res.chunked = true
    rd, wr = IO.pipe
    wr.write(content)
    res.body = rd
    if !keep_open
      wr.close
    end
    wr
  end
end
