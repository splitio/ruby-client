# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'
require 'my_impression_listener'

describe SplitIoClient do
  let(:event_split_update_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850100}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:custom_impression_listener) { MyImpressionListener.new }
  let(:auth_service_url) { 'https://auth.fake.io/api/auth' }
  let(:splits) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits_push.json'))
  end
  let(:splits2) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits_push2.json'))
  end
  let(:splits3) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits_push3.json'))
  end
  let(:auth_body_response) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json'))
  end

  context 'get_treatment' do
    it 'processing split update event' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_fetch)
        end

        stub_request(:get, auth_service_url).to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          impression_listener: custom_impression_listener,
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_push')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1585948850110')).to have_been_made.times(1)
      end
    end

    it 'processing split update event without fetch' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_not_fetch)
        end

        stub_request(:get, auth_service_url).to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          impression_listener: custom_impression_listener,
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('on')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1585948850110')).to have_been_made.times(0)
      end
    end
  end
end

private

def send_content(res, content)
  res.content_type = 'text/event-stream'
  res.status = 200
  res.chunked = true
  rd, wr = IO.pipe
  wr.write(content)
  res.body = rd
  wr.close
  wr
end

def mock_splits_request(splits_json, since)
  stub_request(:get, "https://sdk.split.io/api/splitChanges?since=#{since}")
    .to_return(status: 200, body: splits_json)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
