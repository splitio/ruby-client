# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::EventsSender do
  RSpec.shared_examples 'Events Sender' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
    let(:repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, nil) }
    let(:sender) { described_class.new(repository, config) }

    before :each do
      Redis.new.flushall
    end

    it 'calls #post_events upon destroy' do
      expect(sender).to receive(:post_events).with(no_args).at_least(:once)

      sender.send(:events_thread)

      sender_thread = config.threads[:events_sender]

      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sender_thread.join
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Events Sender', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Events Sender', :redis
  end
end
