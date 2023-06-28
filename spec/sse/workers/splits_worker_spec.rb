# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'
require 'byebug'

describe SplitIoClient::SSE::Workers::SplitsWorker do
  subject { SplitIoClient::SSE::Workers::SplitsWorker }

  let(:splits) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json')) }
  let(:segment1) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json')) }
  let(:segment2) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json')) }
  let(:segment3) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json')) }
  let(:api_key) { 'SplitsWorker-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:split_fetcher) { SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, telemetry_runtime_producer) }
  let(:event_split_update_no_compression)  { SplitIoClient::SSE::EventSource::StreamData.new("data", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":5564531221,"pcn":1234,"c": 0,"d":"eyJ0cmFmZmljVHlwZU5hbWUiOiJ1c2VyIiwiaWQiOiIzM2VhZmE1MC0xYTY1LTExZWQtOTBkZi1mYTMwZDk2OTA0NDUiLCJuYW1lIjoiYmlsYWxfc3BsaXQiLCJ0cmFmZmljQWxsb2NhdGlvbiI6MTAwLCJ0cmFmZmljQWxsb2NhdGlvblNlZWQiOi0xMzY0MTE5MjgyLCJzZWVkIjotNjA1OTM4ODQzLCJzdGF0dXMiOiJBQ1RJVkUiLCJraWxsZWQiOmZhbHNlLCJkZWZhdWx0VHJlYXRtZW50Ijoib2ZmIiwiY2hhbmdlTnVtYmVyIjoxNjg0MzQwOTA4NDc1LCJhbGdvIjoyLCJjb25maWd1cmF0aW9ucyI6e30sImNvbmRpdGlvbnMiOlt7ImNvbmRpdGlvblR5cGUiOiJST0xMT1VUIiwibWF0Y2hlckdyb3VwIjp7ImNvbWJpbmVyIjoiQU5EIiwibWF0Y2hlcnMiOlt7ImtleVNlbGVjdG9yIjp7InRyYWZmaWNUeXBlIjoidXNlciJ9LCJtYXRjaGVyVHlwZSI6IklOX1NFR01FTlQiLCJuZWdhdGUiOmZhbHNlLCJ1c2VyRGVmaW5lZFNlZ21lbnRNYXRjaGVyRGF0YSI6eyJzZWdtZW50TmFtZSI6ImJpbGFsX3NlZ21lbnQifX1dfSwicGFydGl0aW9ucyI6W3sidHJlYXRtZW50Ijoib24iLCJzaXplIjowfSx7InRyZWF0bWVudCI6Im9mZiIsInNpemUiOjEwMH1dLCJsYWJlbCI6ImluIHNlZ21lbnQgYmlsYWxfc2VnbWVudCJ9LHsiY29uZGl0aW9uVHlwZSI6IlJPTExPVVQiLCJtYXRjaGVyR3JvdXAiOnsiY29tYmluZXIiOiJBTkQiLCJtYXRjaGVycyI6W3sia2V5U2VsZWN0b3IiOnsidHJhZmZpY1R5cGUiOiJ1c2VyIn0sIm1hdGNoZXJUeXBlIjoiQUxMX0tFWVMiLCJuZWdhdGUiOmZhbHNlfV19LCJwYXJ0aXRpb25zIjpbeyJ0cmVhdG1lbnQiOiJvbiIsInNpemUiOjB9LHsidHJlYXRtZW50Ijoib2ZmIiwic2l6ZSI6MTAwfV0sImxhYmVsIjoiZGVmYXVsdCBydWxlIn1dfQ=="}'), 'test') }
  let(:event_split_update_gzip_compression)  { SplitIoClient::SSE::EventSource::StreamData.new("data", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":5564531221,"pcn":1234,"c": 1,"d":"H4sIAAkVZWQC/8WST0+DQBDFv0qzZ0ig/BF6a2xjGismUk2MaZopzOKmy9Isy0EbvrtDwbY2Xo233Tdv5se85cCMBs5FtvrYYwIlsglratTMYiKns+chcAgc24UwsF0Xczt2cm5z8Jw8DmPH9wPyqr5zKyTITb2XwpA4TJ5KWWVgRKXYxHWcX/QUkVi264W+68bjaGyxupdCJ4i9KPI9UgyYpibI9Ha1eJnT/J2QsnNxkDVaLEcOjTQrjWBKVIasFefky95BFZg05Zb2mrhh5I9vgsiL44BAIIuKTeiQVYqLotHHLyLOoT1quRjub4fztQuLxj89LpePzytClGCyd9R3umr21ErOcitUh2PTZHY29HN2+JGixMxUujNfvMB3+u2pY1AXySad3z3Mk46msACDp8W7jhly4uUpFt3qD33vDAx0gLpXkx+P1GusbdcE24M2F4uaywwVEWvxSa1Oa13Vjvn2RXradm0xCVuUVBJqNCBGV0DrX4OcLpeb+/lreh3jH8Uw/JQj3UhkxPgCCurdEnADAAA="}'), 'test') }
  let(:event_split_update_zlib_compression)  { SplitIoClient::SSE::EventSource::StreamData.new("data", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":5564531221,"pcn":1234,"c": 2,"d":"eJzEUtFq20AQ/JUwz2c4WZZr3ZupTQh1FKjcQinGrKU95cjpZE6nh9To34ssJ3FNX0sfd3Zm53b2TgietDbF9vXIGdUMha5lDwFTQiGOmTQlchLRPJlEEZeTVJZ6oimWZTpP5WyWQMCNyoOxZPft0ZoA8TZ5aW1TUDCNg4qk/AueM5dQkyiez6IonS6mAu0IzWWSxovFLBZoA4WuhcLy8/bh+xoCL8bagaXJtixQsqbOhq1nCjW7AIVGawgUz+Qqzrr6wB4qmi9m00/JIk7TZCpAtmqgpgJF47SpOn9+UQt16s9YaS71z9NHOYQFha9Pm83Tty0EagrFM/t733RHqIFZH4wb7LDMVh+Ecc4Lv+ZsuQiNH8hXF3hLv39XXNCHbJ+v7x/X2eDmuKLA74sPihVr47jMuRpWfxy1Kwo0GLQjmv1xpBFD3+96gSP5cLVouM7QQaA1vxhK9uKmd853bEZS9jsBSwe2UDDu7mJxd2Mo/muQy81m/2X9I7+N8R/FcPmUd76zjH7X/w4AAP//90glTw=="}'), 'test') }
  let(:event_split_archived_no_compression)  { SplitIoClient::SSE::EventSource::StreamData.new("data", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":5564531221,"pcn":1234,"c": 0,"d":"eyJ0cmFmZmljVHlwZU5hbWUiOiAidXNlciIsICJpZCI6ICIzM2VhZmE1MC0xYTY1LTExZWQtOTBkZi1mYTMwZDk2OTA0NDUiLCAibmFtZSI6ICJiaWxhbF9zcGxpdCIsICJ0cmFmZmljQWxsb2NhdGlvbiI6IDEwMCwgInRyYWZmaWNBbGxvY2F0aW9uU2VlZCI6IC0xMzY0MTE5MjgyLCAic2VlZCI6IC02MDU5Mzg4NDMsICJzdGF0dXMiOiAiQVJDSElWRUQiLCAia2lsbGVkIjogZmFsc2UsICJkZWZhdWx0VHJlYXRtZW50IjogIm9mZiIsICJjaGFuZ2VOdW1iZXIiOiAxNjg0Mjc1ODM5OTUyLCAiYWxnbyI6IDIsICJjb25maWd1cmF0aW9ucyI6IHt9LCAiY29uZGl0aW9ucyI6IFt7ImNvbmRpdGlvblR5cGUiOiAiUk9MTE9VVCIsICJtYXRjaGVyR3JvdXAiOiB7ImNvbWJpbmVyIjogIkFORCIsICJtYXRjaGVycyI6IFt7ImtleVNlbGVjdG9yIjogeyJ0cmFmZmljVHlwZSI6ICJ1c2VyIn0sICJtYXRjaGVyVHlwZSI6ICJJTl9TRUdNRU5UIiwgIm5lZ2F0ZSI6IGZhbHNlLCAidXNlckRlZmluZWRTZWdtZW50TWF0Y2hlckRhdGEiOiB7InNlZ21lbnROYW1lIjogImJpbGFsX3NlZ21lbnQifX1dfSwgInBhcnRpdGlvbnMiOiBbeyJ0cmVhdG1lbnQiOiAib24iLCAic2l6ZSI6IDB9LCB7InRyZWF0bWVudCI6ICJvZmYiLCAic2l6ZSI6IDEwMH1dLCAibGFiZWwiOiAiaW4gc2VnbWVudCBiaWxhbF9zZWdtZW50In0sIHsiY29uZGl0aW9uVHlwZSI6ICJST0xMT1VUIiwgIm1hdGNoZXJHcm91cCI6IHsiY29tYmluZXIiOiAiQU5EIiwgIm1hdGNoZXJzIjogW3sia2V5U2VsZWN0b3IiOiB7InRyYWZmaWNUeXBlIjogInVzZXIifSwgIm1hdGNoZXJUeXBlIjogIkFMTF9LRVlTIiwgIm5lZ2F0ZSI6IGZhbHNlfV19LCAicGFydGl0aW9ucyI6IFt7InRyZWF0bWVudCI6ICJvbiIsICJzaXplIjogMH0sIHsidHJlYXRtZW50IjogIm9mZiIsICJzaXplIjogMTAwfV0sICJsYWJlbCI6ICJkZWZhdWx0IHJ1bGUifV19"}'), 'test') }
  let(:event_split_update_no_definition)  { SplitIoClient::SSE::EventSource::StreamData.new("data", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":5564531221,"pcn":1234,"c": 0, "d":null}'), 'test') }
  let(:synchronizer) do
    segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)
    telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, telemetry_runtime_producer)
    impressions_api = SplitIoClient::Api::Impressions.new(api_key, config, telemetry_runtime_producer)

    repositories = {
      splits: splits_repository,
      segments: segments_repository
    }

    params = {
      split_fetcher: SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, telemetry_runtime_producer),
      segment_fetcher: SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, telemetry_runtime_producer),
      imp_counter: SplitIoClient::Engine::Common::ImpressionCounter.new,
      impressions_sender_adapter: SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api),
      impressions_api: SplitIoClient::Api::Impressions.new(api_key, config, telemetry_runtime_producer)
    }

    SplitIoClient::Engine::Synchronizer.new(repositories, config, params)
  end

  context 'add change number to queue' do
    it 'add change number - must tigger fetch - with retries' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').to_return(status: 200, body: '{"splits": [],"since": -1,"till": 1506703262918}')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918').to_return(status: 200, body: '{"splits": [],"since": 1506703262918,"till": 1506703262918}')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918&till=1506703262919').to_return(status: 200, body: '{"splits": [],"since": 1506703262919,"till": 1506703262919}')

      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start
      worker.add_to_queue(SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_UPDATE", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":1506703262919}'), 'test'))

      sleep 1

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.times(1)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918')).to have_been_made.at_least_times(2)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918&till=1506703262919')).to have_been_made.times(1)
    end

    it 'must trigger fetch' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').to_return(status: 200, body: '{"splits": [],"since": -1,"till": 1506703262916}')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916').to_return(status: 200, body: '{"splits": [],"since": 1506703262916,"till": 1506703262918}')

      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start
      worker.add_to_queue(SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_UPDATE", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":1506703262918}'), 'test'))
      sleep 1

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once
    end

    it 'must not trigger fetch' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').to_return(status: 200, body: '{"splits": [],"since": -1,"till": 1506703262916}')

      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start
      worker.add_to_queue(SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_UPDATE", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":1506703262916}'), 'test'))
      sleep 1

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end

    it 'without start, must not fetch' do
      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.add_to_queue(SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_UPDATE", 123, JSON.parse('{"type":"SPLIT_UPDATE","changeNumber":1506703262918}'), 'test'))

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end
  end

  context 'kill split notification' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')

      split_fetcher.fetch_splits
    end

    it 'must kill split and trigger fetch' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916').to_return(status: 200, body: '{"splits": [],"since": 1506703262916,"till": 1506703262918}')

      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start
      worker.send :kill_feature_flag, SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_KILL", 123, JSON.parse('{"splitName":"FACUNDO_TEST", "defaultTreatment":"on", "type":"SPLIT_KILL","changeNumber":1506703262918}'), 'test')

      sleep(1)

      split = splits_repository.get_split('FACUNDO_TEST')
      expect(split[:killed]).to be_truthy
      expect(split[:defaultTreatment]).to eq('on')
      expect(split[:changeNumber]).to eq(1_506_703_262_918)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once
    end

    it 'must kill split and must not trigger fetch' do
      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)

      worker.start
      worker.send :kill_feature_flag, SplitIoClient::SSE::EventSource::StreamData.new("SPLIT_KILL", 123, JSON.parse('{"splitName":"FACUNDO_TEST", "defaultTreatment":"on", "type":"SPLIT_KILL","changeNumber":1506703262916}'), 'test')

      sleep(1)

      split = splits_repository.get_split('FACUNDO_TEST')
      expect(split[:killed]).to be_truthy
      expect(split[:defaultTreatment]).to eq('on')
      expect(split[:changeNumber]).to eq(1_506_703_262_916)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end
  end

  context 'instant ff update split notification' do

    it 'decode and decompress split update data' do
      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start

      splits_repository.set_change_number(1234)
      worker.add_to_queue(event_split_update_no_compression)
      sleep 1
      split = splits_repository.get_split('bilal_split')
      expect(split[:name] == 'bilal_split')

      splits_repository.set_change_number(1234)
      worker.add_to_queue(event_split_update_gzip_compression)
      sleep 1
      split = splits_repository.get_split('bilal_split')
      expect(split[:name] == 'bilal_split')

      splits_repository.set_change_number(1234)
      worker.add_to_queue(event_split_update_zlib_compression)
      sleep 1
      split = splits_repository.get_split('bilal_split')
      expect(split[:name] == 'bilal_split')

      splits_repository.set_change_number(1234)
      worker.add_to_queue(event_split_archived_no_compression)
      sleep 1
      expect(splits_repository.exists?('bilal_split') == false)
    end

    it 'should not update if definition is nil' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1234').to_return(status: 200, body: '{"splits": [],"since": -1,"till": 1506703262918}')
      worker = subject.new(synchronizer, config, splits_repository, telemetry_runtime_producer)
      worker.start

      splits_repository.set_change_number(1234)
      worker.add_to_queue(event_split_update_no_definition)
      sleep 1
      expect(splits_repository.exists?('bilal_split') == false)
    end
  end

  private

  def mock_split_changes(splits_json)
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_json)
  end

  def mock_segment_changes(segment_name, segment_json, since)
    stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
      .to_return(status: 200, body: segment_json)
  end
end
