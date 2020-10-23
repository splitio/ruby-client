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
    stub_request(:post, 'https://events.split.io/api/metrics/time').to_return(status: 200, body: 'ok')
    stub_request(:post, 'https://events.split.io/api/metrics/counter').to_return(status: 200, body: 'ok')
    stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: 'ok')
  end

  context 'checking logic impressions' do
    it 'get_treament should post 5 impressions - debug mode' do
      factory = SplitIoClient::SplitFactory.new('test_api_key_debug-1', streaming_enabled: false, impressions_mode: :debug)
      debug_client = factory.client

      expect(debug_client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(debug_client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(debug_client.get_treatment('admin', 'FACUNDO_TEST')).to eq 'off'
      expect(debug_client.get_treatment('24', 'Test_Save_1')).to eq 'off'
      expect(debug_client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      impressions = debug_client.instance_variable_get(:@impressions_repository).batch

      sleep 0.5

      expect(impressions.size).to eq 5
    end

    it 'get_treaments should post 11 impressions - debug mode' do
      factory = SplitIoClient::SplitFactory.new('test_api_key_debug-2', streaming_enabled: false, impressions_mode: :debug)
      debug_client = factory.client

      debug_client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      debug_client.get_treatments('admin', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      debug_client.get_treatments('maldo', %w[FACUNDO_TEST Test_Save_1])
      debug_client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      impressions = debug_client.instance_variable_get(:@impressions_repository).batch

      sleep 0.5

      expect(impressions.size).to eq 11
    end

    it 'get_treament should post 3 impressions - optimized mode' do
      factory = SplitIoClient::SplitFactory.new('test_api_key-1', streaming_enabled: false, impressions_mode: :optimized)
      client = factory.client

      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('admin', 'FACUNDO_TEST')).to eq 'off'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      time_frame = SplitIoClient::Engine::Common::ImpressionCounter.truncate_time_frame((Time.now.to_f * 1000.0).to_i)

      impressions = client.instance_variable_get(:@impressions_repository).batch

      sleep 0.5

      expect(impressions.size).to eq 3
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
      .with(
        body: {
          pf: [
            { f: 'FACUNDO_TEST', m: time_frame, rc: 3 },
            { f: 'Test_Save_1', m: time_frame, rc: 2 }
          ]
        }.to_json
      )).to have_been_made
    end

    it 'get_treaments should post 8 impressions - optimized mode' do
      factory = SplitIoClient::SplitFactory.new('test_api_key-2', streaming_enabled: false, impressions_mode: :optimized)
      client = factory.client

      client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      client.get_treatments('admin', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      client.get_treatments('maldo', %w[FACUNDO_TEST Test_Save_1])
      client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      time_frame = SplitIoClient::Engine::Common::ImpressionCounter.truncate_time_frame((Time.now.to_f * 1000.0).to_i)

      impressions = client.instance_variable_get(:@impressions_repository).batch

      sleep 0.5

      expect(impressions.size).to eq 8
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
      .with(
        body: {
          pf: [
            { f: 'FACUNDO_TEST', m: time_frame, rc: 4 },
            { f: 'MAURO_TEST', m: time_frame, rc: 3 },
            { f: 'Test_Save_1', m: time_frame, rc: 4 }
          ]
        }.to_json
      )).to have_been_made
    end
  end
end

private

def mock_split_changes_v2(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_segment_changes_v2(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
