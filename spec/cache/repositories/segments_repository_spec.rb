# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::SegmentsRepository do
  context 'memory adapter' do
    let(:adapter) { SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new }
    let(:config) { SplitIoClient::SplitConfig.new }
    let(:repository) { described_class.new(adapter, config) }

    it 'removes keys' do
      repository.add_to_segment(name: 'foo', added: [1, 2, 3], removed: [])
      expect(repository.get_segment_keys('foo')).to eq([1, 2, 3])

      repository.send(:remove_keys, 'foo', [1, 2, 3])
      expect(repository.get_segment_keys('foo')).to eq([])
    end
  end

  context 'redis adapter' do
    let(:config) { SplitIoClient::SplitConfig.new }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(config.redis_url) }
    let(:repository) { described_class.new(adapter, config) }

    it 'removes keys' do
      repository.add_to_segment(name: 'foo', added: [1, 2, 3], removed: [])
      expect(repository.get_segment_keys('foo')).to eq(%w[1 2 3])

      repository.send(:remove_keys, 'foo', %w[1 2 3])
      expect(repository.get_segment_keys('foo')).to eq([])
    end
  end
end
