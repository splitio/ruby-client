# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: :memory, impressions_mode: :debug) }
  let(:request_decorator) { SplitIoClient::Api::RequestDecorator.new(nil) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([]) }
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:impressions_repository) {SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, 'sdk_key', runtime_producer, request_decorator) }
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
