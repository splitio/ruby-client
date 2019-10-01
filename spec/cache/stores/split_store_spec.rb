# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Stores::SplitStore do
  let(:metrics_repository) do
    SplitIoClient::Cache::Repositories::MetricsRepository.new(config)
  end
  let(:metrics) { SplitIoClient::Metrics.new(100, metrics_repository) }
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
    # let(:adapter) { SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
    let(:store) { described_class.new(splits_repository, '', metrics, config) }

    it 'returns splits since' do
      splits = store.send(:splits_since, -1)

      expect(splits[:splits].count).to eq(2)
    end

    it 'stores data in the cache' do
      store.send(:store_splits)

      expect(store.splits_repository.splits.size).to eq(2)
      expect(store.splits_repository.get_change_number).to eq(store.send(:splits_since, -1)[:till])
    end

    it 'refreshes splits' do
      store.send(:store_splits)

      active_split = store.splits_repository.splits['test_1_ruby']
      expect(active_split[:status]).to eq('ACTIVE')

      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1473413807667')
        .to_return(status: 200, body: archived_splits_json)

      store.send(:store_splits)

      archived_split = store.splits_repository.splits['test_1_ruby']
      expect(archived_split).to be_nil
    end

    it 'rescues from error when split_store#splits_since raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Stores::SplitStore).to receive(:splits_since).and_throw(RuntimeError)

      expect { store.send(:store_splits) }.to_not raise_error
      expect(log.string).to include('Unexpected exception in store_splits')
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
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(config.redis_url) }
    let(:store) { described_class.new(splits_repository, '', metrics, config) }

    it 'returns splits since' do
      splits = store.send(:splits_since, -1)

      expect(splits[:splits].count).to eq(2)
    end

    it 'stores data in the cache' do
      store.send(:store_splits)

      expect(store.splits_repository.splits.size).to eq(2)
      expect(store.splits_repository.get_change_number).to eq(store.send(:splits_since, -1)[:till].to_s)
    end

    it 'refreshes splits' do
      store.send(:store_splits)

      active_split = store.splits_repository.splits['test_1_ruby']
      expect(active_split[:status]).to eq('ACTIVE')

      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1473413807667')
        .to_return(status: 200, body: archived_splits_json)

      store.send(:store_splits)

      archived_split = store.splits_repository.splits['test_1_ruby']
      expect(archived_split).to be_nil
    end
  end
end
