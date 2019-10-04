# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsFormatter do
  RSpec.shared_examples 'Impressions Formatter' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5, cache_adapter: cache_adapter) }
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:formatter) { described_class.new(repository) }
    let(:formatted_impressions) { formatter.send(:call, true) }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }
    let(:treatment3) { { treatment: 'off', label: nil, change_number: nil } }

    before :each do
      Redis.new.flushall
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
                                             changeNumber: 123_456 }]
                        },
                         {
                           testName: :foo2,
                           keyImpressions: [{ keyName: 'matching_key2',
                                              treatment: 'off',
                                              time: 1_478_113_518_285,
                                              bucketingKey: 'foo2',
                                              label: 'custom_label2',
                                              changeNumber: 123_499 }]
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
      repository.add('matching_key', 'foo1', 'foo1', treatment1, 1_478_113_516_902)
      repository.add('matching_key2', 'foo2', 'foo2', treatment2, 1_478_113_518_285)

      expect(formatted_impressions.find { |i| i[:testName] == :foo1 }[:keyImpressions].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:testName] == :foo2 }[:keyImpressions].size).to eq(1)
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Impressions Formatter', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Impressions Formatter', :redis
  end
end
