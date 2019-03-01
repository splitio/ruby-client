# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::MetricsSender do
  RSpec.shared_examples 'metrics sender specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(adapter) }
    let(:sender) { described_class.new(repository, nil) }

    before :each do
      Redis.new.flushall
    end

    it 'calls #post_metrics upon destroy' do
      expect(sender).to receive(:post_metrics).with(no_args)

      sender.send(:metrics_thread)

      sender_thread = SplitIoClient.configuration.threads[:metrics_sender]

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
