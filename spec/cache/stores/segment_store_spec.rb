# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Stores::SegmentStore do
  let(:metrics_repository) do
    SplitIoClient::Cache::Repositories::MetricsRepository.new(SplitIoClient.configuration.metrics_adapter)
  end
  let(:metrics) { SplitIoClient::Metrics.new(100, metrics_repository) }
  let(:segments_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments.json')))
  end
  let(:segments_json2) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments2.json')))
  end
  let(:splits_with_segments_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits3.json')))
  end
  let(:segment_data) do
    [
      { name: 'employees', added: %w[max dan], removed: [], since: -1, till: 1_473_863_075_059 },
      { name: 'employees', added: [], removed: [], since: 1_473_863_075_059, till: 1_473_863_075_059 }
    ]
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments_json)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=1473863075059')
      .to_return(status: 200, body: segments_json2)

    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_with_segments_json)
  end

  context 'memory adapter' do
    before do
      cache_adapter = SplitIoClient::SplitConfig.init_cache_adapter(:memory, :map_adapter)
      SplitIoClient.configuration.cache_adapter = cache_adapter
    end
    let(:adapter) do
      SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new)
    end
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(adapter) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(adapter) }
    let(:segment_store) { described_class.new(segments_repository, '', metrics) }
    let(:split_store) { SplitIoClient::Cache::Stores::SplitStore.new(splits_repository, '', metrics) }

    it 'stores segments' do
      split_store.send(:store_splits)
      segment_store.send(:store_segments)

      expect(segment_store.segments_repository.used_segment_names).to eq(['employees'])
    end

    it 'updates added/removed' do
      segments = segment_store.send(:segments_api).send(:fetch_segment_changes, 'employees', -1)
      expect(segments[:added]).to eq(%w[max dan])
      expect(segments[:removed]).to eq([])

      segments = segment_store.send(:segments_api).send(:fetch_segment_changes, 'employees', 1_473_863_075_059)
      expect(segments[:added]).to eq([])
      expect(segments[:removed]).to eq([])
    end
  end

  context 'redis adapter' do
    before do
      Redis.new.flushall
      cache_adapter = SplitIoClient::SplitConfig.init_cache_adapter(:redis, :map_adapter, redis_url: config.redis_url)
      SplitIoClient.configuration.cache_adapter = cache_adapter
    end
    let(:config) { SplitIoClient::SplitConfig.new }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(config.redis_url) }
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(adapter) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(adapter) }
    let(:segment_store) { described_class.new(segments_repository, '', metrics) }
    let(:split_store) { SplitIoClient::Cache::Stores::SplitStore.new(splits_repository, '', metrics) }

    it 'stores segments' do
      split_store.send(:store_splits)
      segment_store.send(:store_segments)

      expect(segment_store.segments_repository.used_segment_names).to eq(['employees'])
    end

    it 'updates added/removed' do
      segments = segment_store.send(:segments_api).send(:fetch_segment_changes, 'employees', -1)
      expect(segments[:added]).to eq(%w[max dan])
      expect(segments[:removed]).to eq([])

      segments = segment_store.send(:segments_api).send(:fetch_segment_changes, 'employees', 1_473_863_075_059)
      expect(segments[:added]).to eq([])
      expect(segments[:removed]).to eq([])
    end
  end
end
