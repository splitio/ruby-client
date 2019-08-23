# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::MetricsSender do
  RSpec.shared_examples 'Metrics Sender' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
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

  describe 'with Memory Adapter' do
    it_behaves_like 'Metrics Sender', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Metrics Sender', :redis
  end
end
