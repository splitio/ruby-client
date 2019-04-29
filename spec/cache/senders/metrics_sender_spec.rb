# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::MetricsSender do
  RSpec.shared_examples 'metrics sender specs' do |cache_adapter|
    let(:config) do
      config = SplitIoClient::SplitConfig.new
      config.cache_adapter = cache_adapter
      config
    end
    let(:repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config) }
    let(:sender) { described_class.new(repository, nil, config) }

    before :each do
      Redis.new.flushall
    end

    it 'calls #post_metrics upon destroy' do
      expect(sender).to receive(:post_metrics).with(no_args).at_least(:once)

      sender.send(:metrics_thread)

      sender_thread = config.threads[:metrics_sender]

      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sender_thread.join
    end
  end

  include_examples 'metrics sender specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3)
  )
  include_examples 'metrics sender specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )
end
