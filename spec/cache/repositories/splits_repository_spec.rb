require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::SplitsRepository do
  RSpec.shared_examples 'SplitsRepository specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
    let(:repository) { described_class.new(adapter, config) }

    before :all do
      redis = Redis.new
      redis.flushall
    end

    after :all do
      redis = Redis.new
      redis.flushall
    end

    before do
      repository.add_split(name: 'foo')
      repository.add_split(name: 'bar')
      repository.add_split(name: 'baz')
    end

    it 'returns splits names' do
      expect(Set.new(repository.split_names)).to eq(Set.new(%w(foo bar baz)))
    end

    it 'returns splits data' do
      expect(repository.splits).to eq(
        'foo' => { name: 'foo' },
        'bar' => { name: 'bar' },
        'baz' => { name: 'baz' }
      )
    end

    context 'slice is 10' do
      it 'returns data for multiple splits' do
        expect(repository.get_splits(['foo', 'bar', 'baz'], 10)).to eq(
          foo: { name: 'foo' },
          bar: { name: 'bar' },
          baz: { name: 'baz' }
        )
      end
    end

    context 'slice is 2' do
      it 'returns data for multiple splits' do
        expect(repository.get_splits(['foo', 'bar', 'baz'], 2)).to eq(
          foo: { name: 'foo' },
          bar: { name: 'bar' },
          baz: { name: 'baz' }
        )
      end
    end
  end

  include_examples 'SplitsRepository specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new)
  include_examples 'SplitsRepository specs', SplitIoClient::Cache::Adapters::RedisAdapter.new('redis://127.0.0.1:6379/0')
end
