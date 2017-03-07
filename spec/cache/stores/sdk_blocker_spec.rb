require 'spec_helper'

describe SplitIoClient::Cache::Stores::SDKBlocker do
  RSpec.shared_examples 'sdk_blocker specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(ready: 0.1) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(cache_adapter, config) }
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(cache_adapter, config) }
    let(:sdk_blocker) { described_class.new(config, splits_repository, segments_repository) }

    before :each do
      redis = Redis.new
      redis.flushall
    end

    it 'is not ready after initialization' do
      sdk_blocker

      expect(splits_repository.ready?).to be(false)
    end

    it 'is ready when both splits and segments are ready' do
      sdk_blocker.splits_ready!
      sdk_blocker.segments_ready!

      expect(sdk_blocker.ready?).to be true
    end

    it 'throws exception if not ready' do
      expect { sdk_blocker.block }.to raise_error(SplitIoClient::SDKBlockerTimeoutExpiredException)
    end

    it 'runs threads when ready' do
      sdk_blocker.splits_thread = Thread.new { Thread.stop }
      sdk_blocker.segments_thread = Thread.new { Thread.stop }

      sleep 0.1

      expect(sdk_blocker.instance_variable_get(:@splits_thread).status).to eq('sleep')
      expect(sdk_blocker.instance_variable_get(:@segments_thread).status).to eq('sleep')

      sdk_blocker.splits_ready!
      sdk_blocker.segments_ready!

      sdk_blocker.block

      sleep 0.1

      expect(sdk_blocker.instance_variable_get(:@splits_thread).status).to eq(false)
      expect(sdk_blocker.instance_variable_get(:@segments_thread).status).to eq(false)
    end
  end

  include_examples 'sdk_blocker specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3))
  include_examples 'sdk_blocker specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)
end
