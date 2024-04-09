# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Fetchers::SplitFetcher do
  let(:active_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits.json')))
  end
  let(:archived_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits2.json')))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: active_splits_json)
  end

  context 'memory adapter' do
    let(:log) { StringIO.new }
    let(:config) do
      SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        cache_adapter: :memory
      )
    end
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([]) }
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:store) { described_class.new(splits_repository, '', config, telemetry_runtime_producer, SplitIoClient::Api::RequestDecorator.new(nil)) }

    it 'returns splits since' do
      splits = store.send(:splits_since, -1)

      expect(splits[:splits].count).to eq(2)
    end

    it 'fetch data in the cache' do
      store.send(:fetch_splits)

      expect(store.splits_repository.splits.size).to eq(2)
      expect(store.splits_repository.get_change_number).to eq(store.send(:splits_since, -1)[:till])
    end

    it 'refreshes splits' do
      store.send(:fetch_splits)

      active_split = store.splits_repository.splits['test_1_ruby']
      expect(active_split[:status]).to eq('ACTIVE')

      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1473413807667')
        .to_return(status: 200, body: archived_splits_json)

      store.send(:fetch_splits)

      archived_split = store.splits_repository.splits['test_1_ruby']
      expect(archived_split).to be_nil
    end

    it 'rescues from error when split_fetcher#splits_since raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Fetchers::SplitFetcher).to receive(:splits_since).and_throw(RuntimeError)

      expect { store.send(:fetch_splits) }.to_not raise_error
      expect(log.string).to include('Unexpected exception in fetch_splits')
    end
  end

  context 'memory adapter with flag sets' do
    let(:log) { StringIO.new }
    let(:config) do
      SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        cache_adapter: :memory,
        flag_sets_filter: ['set_2']
      )
    end
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new(['set_2']) }
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new(['set_2']) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:store) { described_class.new(splits_repository, '', config, telemetry_runtime_producer, SplitIoClient::Api::RequestDecorator.new(nil)) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?sets=set_2&since=-1')
      .to_return(status: 200, body: active_splits_json)
    end

    it 'returns splits since' do
      splits = store.send(:splits_since, -1)

      expect(splits[:splits].count).to eq(2)
    end

    it 'fetch data in the cache' do
      store.send(:fetch_splits)

      expect(store.splits_repository.splits.size).to eq(1)
      expect(store.splits_repository.get_change_number).to eq(store.send(:splits_since, -1)[:till])
    end

    it 'refreshes splits' do
      store.send(:fetch_splits)
      expect(store.splits_repository.get_split('sample_feature')[:name]).to eq('sample_feature')
      expect(store.splits_repository.get_split('test_1_ruby')).to eq(nil)

      stub_request(:get, 'https://sdk.split.io/api/splitChanges?sets=set_2&since=1473413807667')
        .to_return(status: 200, body: archived_splits_json)

      store.send(:fetch_splits)
      expect(store.splits_repository.get_split('sample_feature')).to eq(nil)

      store.splits_repository.set_change_number(-1)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?sets=set_2&since=-1')
        .to_return(status: 200, body: active_splits_json)

      store.send(:fetch_splits)
      expect(store.splits_repository.get_split('sample_feature')[:name]).to eq('sample_feature')
    end
  end

  context 'redis adapter' do
    let(:log) { StringIO.new }
    let(:config) do
      SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        cache_adapter: :redis
      )
    end
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config) }
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:store) { described_class.new(splits_repository, '', config, telemetry_runtime_producer, SplitIoClient::Api::RequestDecorator.new(nil)) }

    it 'returns splits since' do
      splits = store.send(:splits_since, -1)
      expect(splits[:splits].count).to eq(2)
    end

    it 'fetch data in the cache' do
      store.send(:fetch_splits)
      expect(store.splits_repository.splits.size).to eq(2)
      expect(store.splits_repository.get_change_number).to eq(store.send(:splits_since, -1)[:till].to_s)
    end

    it 'refreshes splits' do
      store.send(:fetch_splits)

      active_split = store.splits_repository.splits['test_1_ruby']
      expect(active_split[:status]).to eq('ACTIVE')

      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1473413807667')
        .to_return(status: 200, body: archived_splits_json)

      store.send(:fetch_splits)

      archived_split = store.splits_repository.splits['test_1_ruby']
      expect(archived_split).to be_nil
    end
  end
end
