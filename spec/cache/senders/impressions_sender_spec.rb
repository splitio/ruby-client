# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSender do
  RSpec.shared_examples 'impressions sender specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(adapter) }
    let(:sender) { described_class.new(repository, nil) }
    let(:formatted_impressions) { sender.send(:formatted_impressions, repository.batch) }
    let(:ip) { SplitIoClient.configuration.machine_ip }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }
    let(:treatment3) { { treatment: 'off', label: nil, change_number: nil } }

    before :each do
      Redis.new.flushall
      SplitIoClient.configuration.impressions_queue_size = 5
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_002)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)
    end

    it 'formats impressions to be sent' do
      expect(formatted_impressions)
        .to match_array([{
                          testName: :foo1,
                          keyImpressions: [{ keyName: 'matching_key',
                                             treatment: 'on',
                                             time: 1_478_113_516_002,
                                             bucketingKey: 'foo1', label: 'custom_label1',
                                             changeNumber: 123_456 }],
                          ip: ip
                        },
                         {
                           testName: :foo2,
                           keyImpressions: [{ keyName: 'matching_key2',
                                              treatment: 'off',
                                              time: 1_478_113_518_285,
                                              bucketingKey: 'foo2',
                                              label: 'custom_label2',
                                              changeNumber: 123_499 }],
                           ip: ip
                         }])
    end

    it 'formats multiple impressions for one key' do
      repository.add('matching_key3', nil, 'foo2', treatment3, 1_478_113_518_900)

      expect(formatted_impressions.find { |i| i[:testName] == :foo1 }[:keyImpressions]).to match_array(
        [
          {
            keyName: 'matching_key',
            treatment: 'on',
            time: 1_478_113_516_002,
            bucketingKey: 'foo1',
            label: 'custom_label1',
            changeNumber: 123_456
          }
        ]
      )

      expect(formatted_impressions.find { |i| i[:testName] == :foo2 }[:keyImpressions]).to match_array(
        [
          {
            keyName: 'matching_key2',
            treatment: 'off',
            time: 1_478_113_518_285,
            bucketingKey: 'foo2',
            label: 'custom_label2',
            changeNumber: 123_499
          },
          {
            keyName: 'matching_key3',
            treatment: 'off',
            time: 1_478_113_518_900,
            bucketingKey: nil,
            label: nil,
            changeNumber: nil
          }
        ]
      )
    end

    it 'filters out impressions with the same key/treatment' do
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_902)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)

      expect(formatted_impressions.find { |i| i[:testName] == :foo1 }[:keyImpressions].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:testName] == :foo2 }[:keyImpressions].size).to eq(1)
    end

    it 'filters out impressions with the same key/treatment legacy' do
      Redis.new.flushall
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_902)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)

      expect(formatted_impressions.find { |i| i[:testName] == :foo1 }[:keyImpressions].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:testName] == :foo2 }[:keyImpressions].size).to eq(1)
    end

    it 'returns the total number of impressions' do
      impressions = formatted_impressions
      expect(sender.send(:impressions_client).total_impressions(impressions)).to eq(2)
    end
  end

  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3)
  )
  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )
end
