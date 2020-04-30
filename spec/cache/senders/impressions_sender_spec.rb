# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSender do
  RSpec.shared_examples 'Impressions Sender' do |cache_adapter|
    let(:config) do
      SplitIoClient::SplitConfig.new(
        cache_adapter: cache_adapter,
        impressions_queue_size: 5
      )
    end
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:sender) { described_class.new(repository, nil, config) }
    let(:formatted_impressions) { SplitIoClient::Cache::Senders::ImpressionsFormatter.new(repository).call(true) }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }

    before :each do
      Redis.new.flushall
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_002)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)
    end

    it 'returns the total number of impressions' do
      expect(sender.send(:impressions_api).total_impressions(formatted_impressions)).to eq(2)
    end

    it 'post impressions with corresponding impressions metadata' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .to_return(status: 200, body: 'ok')

      sender.call

      sleep 0.5
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/bulk')
      .with(
        body: [
          {
            testName: 'foo1',
            keyImpressions: [
              {
                keyName: 'matching_key',
                treatment: 'on',
                time: 1_478_113_516_002,
                bucketingKey: 'foo1',
                label: 'custom_label1',
                changeNumber: 123_456
              }
            ],
            ip: config.machine_ip
          },
          {
            testName: 'foo2',
            keyImpressions: [
              {
                keyName: 'matching_key2',
                treatment: 'off',
                time: 1_478_113_518_285,
                bucketingKey: 'foo2',
                label: 'custom_label2',
                changeNumber: 123_499
              }
            ],
            ip: config.machine_ip
          }
        ].to_json
      )).to have_been_made
    end

    it 'calls #post_impressions upon destroy' do
      expect(sender).to receive(:post_impressions).with(no_args)

      sender.send(:impressions_thread)

      sender_thread = config.threads[:impressions_sender]

      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sender_thread.join
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Impressions Sender', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Impressions Sender', :redis
  end
end
