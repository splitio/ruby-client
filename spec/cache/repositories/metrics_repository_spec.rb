require 'spec_helper'

describe SplitIoClient::Cache::Repositories::MetricsRepository do
  RSpec.shared_examples 'metrics specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new }
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter, config) }
    let(:binary_search) { SplitIoClient::BinarySearchLatencyTracker.new }

    before :each do
      Redis.new.flushall
    end

    it 'does not return zero latencies' do
      repository.add_latency('foo', 0, binary_search)

      expect(repository.latencies.keys).to eq(%w(foo))
    end
  end

  include_examples 'metrics specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)
end
