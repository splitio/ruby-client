# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsFormatter do
  RSpec.shared_examples 'Impressions Formatter' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5, cache_adapter: cache_adapter) }
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:formatter) { described_class.new(repository) }
    let(:formatted_impressions) { formatter.send(:call, true) }
    let(:ip) { config.machine_ip }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }
    let(:treatment3) { { treatment: 'off', label: nil, change_number: nil } }
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:impressions_manager) { SplitIoClient::Engine::Common::ImpressionManager.new(config, repository, impression_counter) }

    before :each do
      Redis.new.flushall
      params = { attributes: {}, time: 1_478_113_516_002 }
      params2 = { attributes: {}, time: 1_478_113_518_285 }

      @impressions = []
      @impressions << impressions_manager.build_impression('matching_key', 'foo1', 'foo1', treatment1, params)
      @impressions << impressions_manager.build_impression('matching_key2', 'foo2', 'foo2', treatment2, params2)
      impressions_manager.track(@impressions)
    end

    it 'formats impressions to be sent' do
      expect(formatted_impressions)
        .to match_array([{
                          f: :foo1,
                          i: [{ k: 'matching_key',
                                t: 'on',
                                m: 1_478_113_516_002,
                                b: 'foo1',
                                r: 'custom_label1',
                                c: 123_456,
                                pt: nil }]
                        },
                         {
                           f: :foo2,
                           i: [{ k: 'matching_key2',
                                 t: 'off',
                                 m: 1_478_113_518_285,
                                 b: 'foo2',
                                 r: 'custom_label2',
                                 c: 123_499,
                                 pt: nil }]
                         }])
    end

    it 'formats multiple impressions for one key' do
      params = { attributes: {}, time: 1_478_113_518_900 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key3', nil, 'foo2', treatment3, params)
      impressions_manager.track(impressions)

      expect(formatted_impressions.find { |i| i[:f] == :foo1 }[:i]).to match_array(
        [
          {
            k: 'matching_key',
            t: 'on',
            m: 1_478_113_516_002,
            b: 'foo1',
            r: 'custom_label1',
            c: 123_456,
            pt: nil
          }
        ]
      )

      expect(formatted_impressions.find { |i| i[:f] == :foo2 }[:i]).to match_array(
        [
          {
            k: 'matching_key2',
            t: 'off',
            m: 1_478_113_518_285,
            b: 'foo2',
            r: 'custom_label2',
            c: 123_499,
            pt: nil
          },
          {
            k: 'matching_key3',
            t: 'off',
            m: 1_478_113_518_900,
            b: nil,
            r: nil,
            c: nil,
            pt: nil
          }
        ]
      )
    end

    it 'filters out impressions with the same key/treatment' do
      impressions_manager.track(@impressions)

      expect(formatted_impressions.find { |i| i[:f] == :foo1 }[:i].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:f] == :foo2 }[:i].size).to eq(1)
    end

    it 'filters out impressions with the same key/treatment legacy' do
      impressions_manager.track(@impressions)

      expect(formatted_impressions.find { |i| i[:f] == :foo1 }[:i].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:f] == :foo2 }[:i].size).to eq(1)
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Impressions Formatter', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Impressions Formatter', :redis
  end
end
