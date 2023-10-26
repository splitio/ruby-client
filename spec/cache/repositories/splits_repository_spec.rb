# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::SplitsRepository do
  RSpec.shared_examples 'Splits Repository' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
    let(:repository) { described_class.new(config, []) }
    let(:repository2) { described_class.new(config, ['set_1', 'set_2']) }

    before :all do
      redis = Redis.new
      redis.flushall
    end

    before do
      # in memory setup
      repository.add_split(name: 'foo', trafficTypeName: 'tt_name_1')
      repository.add_split(name: 'bar', trafficTypeName: 'tt_name_2')
      repository.add_split(name: 'baz', trafficTypeName: 'tt_name_1')

      # redis setup
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_1'), '2'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_2'), '1'
      )
    end

    after do
      repository.remove_split(name: 'foo', trafficTypeName: 'tt_name_1')
      repository.remove_split(name: 'bar', trafficTypeName: 'tt_name_2')
      repository.remove_split(name: 'bar', trafficTypeName: 'tt_name_2')
      repository.remove_split(name: 'qux', trafficTypeName: 'tt_name_3')
      repository.remove_split(name: 'quux', trafficTypeName: 'tt_name_4')
      repository.remove_split(name: 'corge', trafficTypeName: 'tt_name_5')
      repository.remove_split(name: 'corge', trafficTypeName: 'tt_name_6')
    end

    it 'returns splits names' do
      expect(Set.new(repository.split_names)).to eq(Set.new(%w[foo bar baz]))
    end

    it 'returns splits count' do
      expect(repository.splits_count).to eq(3)
    end

    it 'returns traffic types' do
      expect(repository.traffic_type_exists('tt_name_1')).to be true
      expect(repository.traffic_type_exists('tt_name_2')).to be true

      split = { name: 'qux', trafficTypeName: 'tt_name_3' }

      repository.add_split(split)
      repository.remove_split(split)

      expect(repository.traffic_type_exists('tt_name_3')).to be false
    end

    it 'does not increment traffic type count when adding same split twice' do
      split = { name: 'quux', trafficTypeName: 'tt_name_4' }

      repository.add_split(split)
      repository.add_split(split)
      repository.remove_split(split)

      expect(repository.traffic_type_exists('tt_name_4')).to be false
    end

    it 'updates traffic type count accordingly when split changes traffic type' do
      split = { name: 'corge', trafficTypeName: 'tt_name_5' }

      repository.add_split(split)
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be true

      split = { name: 'corge', trafficTypeName: 'tt_name_6' }

      repository.add_split(split)

      # mimicing synchronizer internals
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '0'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_6'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be false
      expect(repository.traffic_type_exists('tt_name_6')).to be true
    end

    it 'returns splits data' do
      expect(repository.splits).to eq(
        'foo' => { name: 'foo', trafficTypeName: 'tt_name_1' },
        'bar' => { name: 'bar', trafficTypeName: 'tt_name_2' },
        'baz' => { name: 'baz', trafficTypeName: 'tt_name_1' }
      )
    end

    it 'check without flagset filter' do
      repository.add_split(name: 'split1', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      repository.add_split(name: 'split2', trafficTypeName: 'tt_name_2')
      repository.add_split(name: 'split3', trafficTypeName: 'tt_name_1', sets: ['set_2'])

      expect(repository.is_flag_set_exist('set_1')).to be true
      expect(repository.is_flag_set_exist('set_2')).to be true
      expect(repository.is_flag_set_exist('set_3')).to be false
      expect(repository.get_feature_flags_by_sets(['set_3'])).to eq([])
      expect(repository.get_feature_flags_by_sets(['set_1'])).to eq(['split1'])
      expect(repository.get_feature_flags_by_sets(['set_2'])).to eq(['split3'])
      expect(repository.get_feature_flags_by_sets(['set_2', 'set_1']).sort).to eq(['split1', 'split3'])

      repository.add_split(name: 'split4', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository.get_feature_flags_by_sets(['set_1'])).to eq(['split1', 'split4'])

      repository.remove_split(name: 'split1', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository.is_flag_set_exist('set_1')).to be true
      expect(repository.get_feature_flags_by_sets(['set_1'])).to eq(['split4'])

      repository.remove_split(name: 'split4', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository.is_flag_set_exist('set_1')).to be false
      expect(repository.get_feature_flags_by_sets(['set_1'])).to eq([])
      expect(repository.get_feature_flags_by_sets(['set_2', 'set_1']).sort).to eq(['split3'])
    end

    it 'check with flagset filter' do
      repository2.add_split(name: 'split1', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      repository2.add_split(name: 'split2', trafficTypeName: 'tt_name_2', sets: ['set_3'])
      repository2.add_split(name: 'split3', trafficTypeName: 'tt_name_1', sets: ['set_2'])

      expect(repository2.is_flag_set_exist('set_1')).to be true
      expect(repository2.is_flag_set_exist('set_2')).to be true
      expect(repository2.is_flag_set_exist('set_3')).to be false
      expect(repository2.get_feature_flags_by_sets(['set_3'])).to eq([])
      expect(repository2.get_feature_flags_by_sets(['set_1'])).to eq(['split1'])
      expect(repository2.get_feature_flags_by_sets(['set_2'])).to eq(['split3'])
      expect(repository2.get_feature_flags_by_sets(['set_2', 'set_1']).sort).to eq(['split1', 'split3'])

      repository2.add_split(name: 'split4', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository2.get_feature_flags_by_sets(['set_1'])).to eq(['split1', 'split4'])

      repository2.remove_split(name: 'split1', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository2.is_flag_set_exist('set_1')).to be true
      expect(repository2.get_feature_flags_by_sets(['set_1'])).to eq(['split4'])

      repository2.remove_split(name: 'split4', trafficTypeName: 'tt_name_1', sets: ['set_1'])
      expect(repository2.is_flag_set_exist('set_1')).to be true
      expect(repository2.get_feature_flags_by_sets(['set_1'])).to eq([])
      expect(repository2.get_feature_flags_by_sets(['set_2', 'set_1']).sort).to eq(['split3'])
    end

  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Splits Repository', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Splits Repository', :redis
  end
end
