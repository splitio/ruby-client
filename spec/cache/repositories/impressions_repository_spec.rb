require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'impressions specs' do |cache_adapter|
    context 'memory adapter' do
      let(:adapter) { cache_adapter }
      let(:repository) { described_class.new(adapter) }

      it 'adds impressions' do
        repository.add('foo', foo: 'foo', bar: 'bar')
        repository.add('foo2', foo2: 'foo2', bar2: 'bar2')
        repository.add('foo3', foo3: 'foo3', bar3: 'bar3')

        expect(Set.new(repository.clear)).to eq(
          Set.new([
            { 'foo' => 'foo', 'bar' => 'bar' },
            { 'foo2' => 'foo2', 'bar2' => 'bar2' },
            { 'foo3' => 'foo3', 'bar3' => 'bar3' },
          ])
        )

        expect(repository.clear).to eq([])
      end
    end
  end

  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new
  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)
end
