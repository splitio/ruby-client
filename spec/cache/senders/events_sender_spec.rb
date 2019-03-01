# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::EventsSender do
  RSpec.shared_examples 'events sender specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(adapter) }
    let(:sender) { described_class.new(repository, nil) }
    let(:ip) { SplitIoClient.configuration.machine_ip }

    before :each do
      Redis.new.flushall
    end

    it 'calls #post_events upon destroy' do
      expect(sender).to receive(:post_events).with(no_args)

      sender.send(:events_thread)

      sender_thread = SplitIoClient.configuration.threads[:events_sender]

      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sender_thread.join
    end
  end

  include_examples 'events sender specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3)
  )
  include_examples 'events sender specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )
end
