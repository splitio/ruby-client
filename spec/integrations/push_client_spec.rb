# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient do
  let(:event_split_iff_update_no_compression) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111, \\\"pcn\\\":1585948850110,\\\"c\\\": 0,\\\"d\\\":\\\"eyJ0cmFmZmljVHlwZU5hbWUiOiJ1c2VyIiwiaWQiOiIzM2VhZmE1MC0xYTY1LTExZWQtOTBkZi1mYTMwZDk2OTA0NDUiLCJuYW1lIjoiYmlsYWxfc3BsaXQiLCJ0cmFmZmljQWxsb2NhdGlvbiI6MTAwLCJ0cmFmZmljQWxsb2NhdGlvblNlZWQiOi0xMzY0MTE5MjgyLCJzZWVkIjotNjA1OTM4ODQzLCJzdGF0dXMiOiJBQ1RJVkUiLCJraWxsZWQiOmZhbHNlLCJkZWZhdWx0VHJlYXRtZW50Ijoib2ZmIiwiY2hhbmdlTnVtYmVyIjoxNjg0MzQwOTA4NDc1LCJhbGdvIjoyLCJjb25maWd1cmF0aW9ucyI6e30sImNvbmRpdGlvbnMiOlt7ImNvbmRpdGlvblR5cGUiOiJST0xMT1VUIiwibWF0Y2hlckdyb3VwIjp7ImNvbWJpbmVyIjoiQU5EIiwibWF0Y2hlcnMiOlt7ImtleVNlbGVjdG9yIjp7InRyYWZmaWNUeXBlIjoidXNlciJ9LCJtYXRjaGVyVHlwZSI6IklOX1NFR01FTlQiLCJuZWdhdGUiOmZhbHNlLCJ1c2VyRGVmaW5lZFNlZ21lbnRNYXRjaGVyRGF0YSI6eyJzZWdtZW50TmFtZSI6ImJpbGFsX3NlZ21lbnQifX1dfSwicGFydGl0aW9ucyI6W3sidHJlYXRtZW50Ijoib24iLCJzaXplIjowfSx7InRyZWF0bWVudCI6Im9mZiIsInNpemUiOjEwMH1dLCJsYWJlbCI6ImluIHNlZ21lbnQgYmlsYWxfc2VnbWVudCJ9LHsiY29uZGl0aW9uVHlwZSI6IlJPTExPVVQiLCJtYXRjaGVyR3JvdXAiOnsiY29tYmluZXIiOiJBTkQiLCJtYXRjaGVycyI6W3sia2V5U2VsZWN0b3IiOnsidHJhZmZpY1R5cGUiOiJ1c2VyIn0sIm1hdGNoZXJUeXBlIjoiQUxMX0tFWVMiLCJuZWdhdGUiOmZhbHNlfV19LCJwYXJ0aXRpb25zIjpbeyJ0cmVhdG1lbnQiOiJvbiIsInNpemUiOjB9LHsidHJlYXRtZW50Ijoib2ZmIiwic2l6ZSI6MTAwfV0sImxhYmVsIjoiZGVmYXVsdCBydWxlIn1dfQ==\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_iff_update_incorrect_pcn) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111, \\\"pcn\\\":1234,\\\"c\\\": 0,\\\"d\\\":\\\"eyJ0cmFmZmljVHlwZU5hbWUiOiJ1c2VyIiwiaWQiOiIzM2VhZmE1MC0xYTY1LTExZWQtOTBkZi1mYTMwZDk2OTA0NDUiLCJuYW1lIjoiYmlsYWxfc3BsaXQiLCJ0cmFmZmljQWxsb2NhdGlvbiI6MTAwLCJ0cmFmZmljQWxsb2NhdGlvblNlZWQiOi0xMzY0MTE5MjgyLCJzZWVkIjotNjA1OTM4ODQzLCJzdGF0dXMiOiJBQ1RJVkUiLCJraWxsZWQiOmZhbHNlLCJkZWZhdWx0VHJlYXRtZW50Ijoib2ZmIiwiY2hhbmdlTnVtYmVyIjoxNjg0MzQwOTA4NDc1LCJhbGdvIjoyLCJjb25maWd1cmF0aW9ucyI6e30sImNvbmRpdGlvbnMiOlt7ImNvbmRpdGlvblR5cGUiOiJST0xMT1VUIiwibWF0Y2hlckdyb3VwIjp7ImNvbWJpbmVyIjoiQU5EIiwibWF0Y2hlcnMiOlt7ImtleVNlbGVjdG9yIjp7InRyYWZmaWNUeXBlIjoidXNlciJ9LCJtYXRjaGVyVHlwZSI6IklOX1NFR01FTlQiLCJuZWdhdGUiOmZhbHNlLCJ1c2VyRGVmaW5lZFNlZ21lbnRNYXRjaGVyRGF0YSI6eyJzZWdtZW50TmFtZSI6ImJpbGFsX3NlZ21lbnQifX1dfSwicGFydGl0aW9ucyI6W3sidHJlYXRtZW50Ijoib24iLCJzaXplIjowfSx7InRyZWF0bWVudCI6Im9mZiIsInNpemUiOjEwMH1dLCJsYWJlbCI6ImluIHNlZ21lbnQgYmlsYWxfc2VnbWVudCJ9LHsiY29uZGl0aW9uVHlwZSI6IlJPTExPVVQiLCJtYXRjaGVyR3JvdXAiOnsiY29tYmluZXIiOiJBTkQiLCJtYXRjaGVycyI6W3sia2V5U2VsZWN0b3IiOnsidHJhZmZpY1R5cGUiOiJ1c2VyIn0sIm1hdGNoZXJUeXBlIjoiQUxMX0tFWVMiLCJuZWdhdGUiOmZhbHNlfV19LCJwYXJ0aXRpb25zIjpbeyJ0cmVhdG1lbnQiOiJvbiIsInNpemUiOjB9LHsidHJlYXRtZW50Ijoib2ZmIiwic2l6ZSI6MTAwfV0sImxhYmVsIjoiZGVmYXVsdCBydWxlIn1dfQ==\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_iff_update_missing_definition) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111, \\\"pcn\\\":1585948850110,\\\"c\\\": 0,\\\"d\\\":\\\"\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_iff_update_incorrect_compression) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111, \\\"pcn\\\":1585948850110,\\\"c\\\": 4,\\\"d\\\":\\\"eyJ0cmFmZmljVHlwZU5hbWUiOiJ1c2VyIiwiaWQiOiIzM2VhZmE1MC0xYTY1LTExZWQtOTBkZi1mYTMwZDk2OTA0NDUiLCJuYW1lIjoiYmlsYWxfc3BsaXQiLCJ0cmFmZmljQWxsb2NhdGlvbiI6MTAwLCJ0cmFmZmljQWxsb2NhdGlvblNlZWQiOi0xMzY0MTE5MjgyLCJzZWVkIjotNjA1OTM4ODQzLCJzdGF0dXMiOiJBQ1RJVkUiLCJraWxsZWQiOmZhbHNlLCJkZWZhdWx0VHJlYXRtZW50Ijoib2ZmIiwiY2hhbmdlTnVtYmVyIjoxNjg0MzQwOTA4NDc1LCJhbGdvIjoyLCJjb25maWd1cmF0aW9ucyI6e30sImNvbmRpdGlvbnMiOlt7ImNvbmRpdGlvblR5cGUiOiJST0xMT1VUIiwibWF0Y2hlckdyb3VwIjp7ImNvbWJpbmVyIjoiQU5EIiwibWF0Y2hlcnMiOlt7ImtleVNlbGVjdG9yIjp7InRyYWZmaWNUeXBlIjoidXNlciJ9LCJtYXRjaGVyVHlwZSI6IklOX1NFR01FTlQiLCJuZWdhdGUiOmZhbHNlLCJ1c2VyRGVmaW5lZFNlZ21lbnRNYXRjaGVyRGF0YSI6eyJzZWdtZW50TmFtZSI6ImJpbGFsX3NlZ21lbnQifX1dfSwicGFydGl0aW9ucyI6W3sidHJlYXRtZW50Ijoib24iLCJzaXplIjowfSx7InRyZWF0bWVudCI6Im9mZiIsInNpemUiOjEwMH1dLCJsYWJlbCI6ImluIHNlZ21lbnQgYmlsYWxfc2VnbWVudCJ9LHsiY29uZGl0aW9uVHlwZSI6IlJPTExPVVQiLCJtYXRjaGVyR3JvdXAiOnsiY29tYmluZXIiOiJBTkQiLCJtYXRjaGVycyI6W3sia2V5U2VsZWN0b3IiOnsidHJhZmZpY1R5cGUiOiJ1c2VyIn0sIm1hdGNoZXJUeXBlIjoiQUxMX0tFWVMiLCJuZWdhdGUiOmZhbHNlfV19LCJwYXJ0aXRpb25zIjpbeyJ0cmVhdG1lbnQiOiJvbiIsInNpemUiOjB9LHsidHJlYXRtZW50Ijoib2ZmIiwic2l6ZSI6MTAwfV0sImxhYmVsIjoiZGVmYXVsdCBydWxlIn1dfQ==\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update_missing_change_number) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850100}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 1585948850111, \\\"defaultTreatment\\\" : \\\"off_kill\\\", \\\"splitName\\\" : \\\"push_test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 1585948850100, \\\"defaultTreatment\\\" : \\\"off_kill\\\", \\\"splitName\\\" : \\\"push_test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 1470947453879, \\\"segmentName\\\" : \\\"segment3\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": -1, \\\"segmentName\\\" : \\\"segment3\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_occupancy_with_publishers) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_pri\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":2}}\",\"name\":\"[meta]occupancy\"}\n\n\r\nfb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1585948850111}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_occupancy_without_publishers) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_sec\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":0}}\",\"name\":\"[meta]occupancy\"}\n\n\r\nd4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_pri\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":0}}\",\"name\":\"[meta]occupancy\"}\n\n\r\n" }
  let(:event_control_STREAMING_PAUSED) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"clientId\":\"emptyClientId\",\"timestamp\":1582056812285,\"encoding\":\"json\",\"channel\":\"control_pri\",\"data\":\"{\\\"type\\\":\\\"CONTROL\\\",\\\"controlType\\\":\\\"STREAMING_PAUSED\\\"}\"}\n\n\r\n" }
  let(:event_control_STREAMING_RESUMED) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"clientId\":\"emptyClientId\",\"timestamp\":1582056812285,\"encoding\":\"json\",\"channel\":\"control_pri\",\"data\":\"{\\\"type\\\":\\\"CONTROL\\\",\\\"controlType\\\":\\\"STREAMING_RESUMED\\\"}\"}\n\n\r\n" }
  let(:event_control_STREAMING_DISABLED) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"clientId\":\"emptyClientId\",\"timestamp\":1582056812285,\"encoding\":\"json\",\"channel\":\"control_pri\",\"data\":\"{\\\"type\\\":\\\"CONTROL\\\",\\\"controlType\\\":\\\"STREAMING_DISABLED\\\"}\"}\n\n\r\n" }
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
  let(:segment3) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json'))
  end
  let(:segment3_updated) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3_updated.json'))
  end
  let(:auth_body_response) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json'))
  end

  before do
    stub_request(:any, /https:\/\/events.*/).to_return(status: 200, body: '')
    stub_request(:any, /https:\/\/telemetry.*/).to_return(status: 200, body: 'ok')
  end

  context 'SPLIT_UPDATE' do
    it 'processing split update event' do
      mock_splits_request(splits, '-1')
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url,
#          features_refresh_rate: 9999,
          telemetry_refresh_rate: 99999,
          impressions_refresh_rate: 99999
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')).to have_been_made.at_least_times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110')).to have_been_made.times(1)
        client.destroy
      end
    end

    it 'processing split update event without fetch' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_segment_changes('segment3', segment3, '-1')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_not_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(1)
        expect(client.get_treatment('admin', 'push_test')).to eq('on')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110')).to have_been_made.times(0)
        client.destroy
      end
    end

    it 'processing split update missing change number' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_missing_change_number)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(1)
        expect(client.get_treatment('admin', 'push_test')).to eq('on')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110')).to have_been_made.times(0)
      end
    end

    it 'processing split iff update event' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111").to_return(status: 200, body: '')
      stub_request(:get, "https://sdk.split.io/api/segmentChanges/bilal_segment?since=-1").to_return(status: 200, body: '')
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_iff_update_no_compression)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready

        treatment = 'control'
        for i in 1..5 do
          sleep(1)
          treatment = client.get_treatment('admin', 'bilal_split')
          break if treatment != 'control'
        end

        expect(treatment).to eq('off')
      end
    end

    it 'processing incorrect split iff update event' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_iff_update_incorrect_pcn)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'bilal_split')).to eq('control')
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
      end
    end

    it 'processing split iff update event missing definition' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_iff_update_missing_definition)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'bilal_split')).to eq('control')
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
      end
    end

    it 'processing split iff update event incorrect compression' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_iff_update_incorrect_compression)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'bilal_split')).to eq('control')
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
      end
    end
  end

  context 'SPLIT_KILL' do
    it 'processing split kill event' do
      mock_splits_request(splits, '-1')
      mock_splits_request(splits2, '1585948850109')
      mock_splits_request(splits3, '1585948850110')
      mock_segment_changes('segment3', segment3, '-1')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key=3',
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110')).to have_been_made.at_least_times(1)
        client.destroy
      end
    end

    it 'processing split kill event without fetch' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110').to_return(status: 200, body: '')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_not_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('on')
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850109')).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850110')).to have_been_made.times(0)
        client.destroy
      end
    end
  end

  context 'SEGMENT UPDATE' do
    it 'processing segment update event with fetch' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1&till=1470947453879').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')
        .to_return({ status: 200, body: segment3 }, { status: 200, body: segment3 }, { status: 200, body: segment3_updated })

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('test_in_segment', 'feature_segment')).to eq('def_test')
        client.destroy
      end
    end

    it 'processing segment update event without fetch' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')
        .to_return(status: 200, body: segment3)

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_not_fetch)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('test_in_segment', 'feature_segment')).to eq('on')
        client.destroy
      end
    end
  end

  context 'OCCUPANCY' do
    it 'occupancy event with publishers available' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_occupancy_with_publishers)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(3)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        client.destroy
      end
    end

    it 'occupancy event without publishers available' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)
      mock_segment_changes('segment3', segment3, '-1')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_occupancy_without_publishers)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        client.destroy
      end
    end
  end

  context 'CONTROL MESSAGE' do
    it 'STREAMING_PAUSED' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)
      mock_segment_changes('segment3', segment3, '-1')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_control_STREAMING_PAUSED)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        client.destroy
      end
    end

    it 'STREAMING_RESUMED' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)
      mock_segment_changes('segment3', segment3, '-1')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_control_STREAMING_RESUMED)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        client.destroy
      end
    end

    it 'STREAMING_DISABLED' do
      mock_splits_request(splits, -1)
      mock_splits_request(splits2, 1_585_948_850_109)
      mock_splits_request(splits3, 1_585_948_850_110)
      mock_segment_changes('segment3', segment3, '-1')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1585948850111').to_return(status: 200, body: '')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_control_STREAMING_DISABLED)
        end

        stub_request(:get, auth_service_url + "?s=1.1").to_return(status: 200, body: auth_body_response)

        streaming_service_url = server.base_uri
        factory = SplitIoClient::SplitFactory.new(
          'test_api_key',
          streaming_enabled: true,
          streaming_service_url: streaming_service_url,
          auth_service_url: auth_service_url
        )

        client = factory.client
        client.block_until_ready(1)
        sleep(2)
        expect(client.get_treatment('admin', 'push_test')).to eq('after_fetch')
        client.destroy
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
    stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=#{since}")
      .to_return(status: 200, body: splits_json)
  end

  def mock_segment_changes(segment_name, segment_json, since)
    stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
      .to_return(status: 200, body: segment_json)
  end
end
