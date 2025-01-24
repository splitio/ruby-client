# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:splits) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json'))
  end

  let(:segment1) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json'))
  end

  let(:segment2) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json'))
  end

  let(:segment3) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json'))
  end

  before do
    mock_split_changes_v2(splits)
    mock_segment_changes_v2('segment1', segment1, '-1')
    mock_segment_changes_v2('segment1', segment1, '1470947453877')
    mock_segment_changes_v2('segment2', segment2, '-1')
    mock_segment_changes_v2('segment2', segment2, '1470947453878')
    mock_segment_changes_v2('segment3', segment3, '-1')
    stub_request(:post, 'https://events.split.io/api/testImpressions/bulk').to_return(status: 200, body: 'ok')
    stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: 'ok')
  end

  context 'checking logic impressions' do
    it 'get_treament should post 7 impressions - debug mode' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916').to_return(status: 200, body: '')
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=-1").to_return(status: 200, body: splits, headers: {})

      factory = SplitIoClient::SplitFactory.new('test_api_key_debug-1', streaming_enabled: false, impressions_mode: :debug)
      debug_client = factory.client
      debug_client.block_until_ready(2)
      sleep 1

      expect(debug_client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      treatments = {:FACUNDO_TEST=>"on"}
      expect(debug_client.get_treatments_by_flag_set('nico_test', 'set_3')).to eq treatments
      treatments = {:FACUNDO_TEST=>"off"}
      expect(debug_client.get_treatments_by_flag_sets('admin', ['set_3'])).to eq treatments
      treatments = {:FACUNDO_TEST=>{:treatment=>"off", :config=>nil}}
      expect(debug_client.get_treatments_with_config_by_flag_set('admin', 'set_3')).to eq treatments
      expect(debug_client.get_treatments_with_config_by_flag_sets('admin', ['set_3'])).to eq treatments
      expect(debug_client.get_treatment('24', 'Test_Save_1')).to eq 'off'
      expect(debug_client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      impressions = debug_client.instance_variable_get(:@impressions_repository).batch

      sleep 0.5

      expect(impressions.size).to eq 7
    end

    it 'get_treaments should post 9 impressions - debug mode' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916').to_return(status: 200, body: '')

      factory = SplitIoClient::SplitFactory.new('test_api_key_debug-2', streaming_enabled: false, impressions_mode: :debug)
      debug_client = factory.client
      debug_client.block_until_ready(2)

      debug_client.get_treatments('admin', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      debug_client.get_treatments('maldo', %w[FACUNDO_TEST Test_Save_1])
      debug_client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      expect(debug_client.get_treatments_by_flag_set('admin', 'set_3')).to eq ({:FACUNDO_TEST=>"off"})

      impressions = debug_client.instance_variable_get(:@impressions_repository).batch

      sleep 1

      expect(impressions.size).to eq 9
    end

    it 'get_treament should post 3 impressions - optimized mode' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916').to_return(status: 200, body: '')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage').to_return(status: 200, body: '')

      factory = SplitIoClient::SplitFactory.new('test_api_key-1', streaming_enabled: false, impressions_mode: :optimized, impressions_refresh_rate: 60)
      client = factory.client
      client.block_until_ready(2)

      expect(client.get_treatments_by_flag_sets('nico_test', ['set_3'])).to eq ({:FACUNDO_TEST=>"on"})
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('admin', 'FACUNDO_TEST')).to eq 'off'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      time_frame = SplitIoClient::Engine::Common::ImpressionCounter.truncate_time_frame((Time.now.to_f * 1000.0).to_i)

      sleep 1
      client.destroy

      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
      .with(
        body: {
          pf: [
            { f: 'FACUNDO_TEST', m: time_frame, rc: 1 },
            { f: 'Test_Save_1', m: time_frame, rc: 1 }
          ]
        }.to_json
      )).to have_been_made
    end

    it 'get_treaments should post 8 impressions - optimized mode' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916').to_return(status: 200, body: '')

      factory = SplitIoClient::SplitFactory.new('test_api_key-2', streaming_enabled: false, impressions_mode: :optimized)
      client = factory.client

      client.block_until_ready(2)
      sleep 1

      client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      client.get_treatments('admin', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      client.get_treatments('maldo', %w[FACUNDO_TEST Test_Save_1])
      client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      time_frame = SplitIoClient::Engine::Common::ImpressionCounter.truncate_time_frame((Time.now.to_f * 1000.0).to_i)

      client.destroy
      sleep 0.5

      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
      .with(
        body: {
          pf: [
            { f: 'FACUNDO_TEST', m: time_frame, rc: 2 },
            { f: 'MAURO_TEST', m: time_frame, rc: 2 },
            { f: 'Test_Save_1', m: time_frame, rc: 2 }
          ]
        }.to_json
      )).to have_been_made
    end
  end
end

private

def mock_split_changes_v2(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_segment_changes_v2(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
