# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  context 'split client methods' do
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: :memory, impressions_mode: :debug) }
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([]) }
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
    let(:impressions_repository) {SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, 'sdk_key', runtime_producer) }
    let(:impression_manager) { SplitIoClient::Engine::Common::ImpressionManager.new(config, impressions_repository, SplitIoClient::Engine::Common::NoopImpressionCounter.new, runtime_producer, SplitIoClient::Observers::NoopImpressionObserver.new, SplitIoClient::Engine::Impressions::NoopUniqueKeysTracker.new) }
    let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
    let(:evaluator) { SplitIoClient::Engine::Parser::Evaluator.new(segments_repository, splits_repository, config) }
    let(:split_client) { SplitIoClient::SplitClient.new('sdk_key', {:splits => splits_repository, :segments => segments_repository, :impressions => impressions_repository, :events => events_repository}, nil, config, impression_manager, evaluation_producer, evaluator, SplitIoClient::Validators.new(config)) }

    let(:splits) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json'))
    end

    before do
      splits_repository.update([JSON.parse(splits,:symbolize_names => true)[:splits][2]], [], -1)
    end

    it 'check getting treatments' do
      expect(split_client.get_treatment('key', 'testing222')).to eq('off')
      expect(split_client.get_treatments('key', ['testing222'])).to eq({:testing222 => 'off'})
      expect(split_client.get_treatment_with_config('key', 'testing222')).to eq({:treatment => 'off', :config => nil})
      expect(split_client.get_treatments_with_config('key', ['testing222'])).to eq({:testing222 => {:treatment => 'off', :config => nil}})
      expect(split_client.get_treatments_by_flag_set('key', 'set_1')).to eq({:testing222 => 'off'})
      expect(split_client.get_treatments_by_flag_sets('key', ['set_2'])).to eq({:testing222 => 'off'})
      expect(split_client.get_treatments_with_config_by_flag_set('key', 'set_1')).to eq({:testing222 => {:treatment => 'off', :config => nil}})
      expect(split_client.get_treatments_with_config_by_flag_sets('key', ['set_2'])).to eq({:testing222 => {:treatment => 'off', :config => nil}})
    end

    it 'check track' do
      expect(split_client.track('key', 'account', 'event', 1)).to eq(true)
    end
  end

  context 'post data before shutdown' do
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

    it 'posting impressions and events' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits)
      stub_request(:post, 'https://events.split.io/api/events/bulk').to_return(status: 200, body: '')
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk').to_return(status: 200, body: '')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage').to_return(status: 200, body: '')
      stub_request(:get, "https://sdk.split.io/api/splitChanges?since=1506703262916").to_return(status: 200, body: 'ok')
      stub_request(:get, "https://sdk.split.io/api/splitChanges?sets=set_3&since=1506703262916").to_return(status: 200, body: 'ok')
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')

      factory5 = SplitIoClient::SplitFactory.new('test_api_key',
          features_refresh_rate: 9999,
          streaming_enabled: false)
      client5 = factory5.client
      client5.block_until_ready

      for a in 1..100 do
        expect(client5.track('id' + a.to_s, 'account', 'event', 1)).to be_truthy
      end
      expect(client5.instance_variable_get(:@events_repository).empty?).to be(false)

      expect(client5.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client5.instance_variable_get(:@impressions_repository).empty?).to be(false)

      client5.destroy()

      expect(client5.instance_variable_get(:@impressions_repository).empty?).to be(true)
      expect(client5.instance_variable_get(:@events_repository).empty?).to be(true)
    end
  end
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
