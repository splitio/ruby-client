# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSender do
  RSpec.shared_examples 'impressions sender specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(adapter) }
    let(:sender) { described_class.new(repository, nil) }
    let(:formatted_impressions) { ImpressionsFormatter.new(repository).call(true) }
    let(:ip) { SplitIoClient.configuration.machine_ip }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }

    before :each do
      Redis.new.flushall
      SplitIoClient.configuration.impressions_queue_size = 5
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_002)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)
    end

    it 'returns the total number of impressions' do
      expect(sender.send(:impressions_api).total_impressions(formatted_impressions)).to eq(2)
    end

    it 'calls #post_impressions upon destroy' do
      expect(sender).to receive(:post_impressions).with(no_args)

      sender.send(:impressions_thread)

      sender_thread = SplitIoClient.configuration.threads[:impressions_sender]

      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sender_thread.join
    end
  end

  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3)
  )
  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )
end
