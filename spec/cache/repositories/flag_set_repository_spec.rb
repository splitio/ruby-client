# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe "Flag set repository" do
  context 'test memory' do
    it 'test add/delete' do
      flag_set = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new []
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})

      flag_set.add_flag_set('set_1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(true)
      expect(flag_set.get_flag_sets(['set_1'])).to eq([])

      flag_set.add_flag_set('set_2')
      expect(flag_set.flag_set_exist?('set_2')).to eq(true)
      expect(flag_set.get_flag_sets(['set_2'])).to eq([])

      flag_set.remove_flag_set('set_1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(false)

      flag_set.remove_flag_set('set_2')
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})
    end

    it 'test add/delete feature flags to flag sets' do
      flag_set = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new []
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})

      flag_set.add_flag_set('set_1')
      flag_set.add_feature_flag_to_flag_set('set_1', 'feature1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(true)
      expect(flag_set.get_flag_sets(['set_1'])).to eq(['feature1'])

      flag_set.add_feature_flag_to_flag_set('set_1', 'feature2')
      expect(flag_set.get_flag_sets(['set_1'])).to eq(['feature1', 'feature2'])

      flag_set.remove_feature_flag_from_flag_set('set_1', 'feature1')
      expect(flag_set.get_flag_sets(['set_1'])).to eq(['feature2'])

      flag_set.remove_feature_flag_from_flag_set('set_1', 'feature2')
      expect(flag_set.get_flag_sets(['set_1'])).to eq([])
    end
  end

  context 'test redis' do
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new('redis://127.0.0.1:6379/0') }

    it 'test get and exist' do
      Redis.new.flushall

      adapter.add_to_set('SPLITIO.flagSet.set_1', 'feature1')
      adapter.add_to_set('SPLITIO.flagSet.set_2', 'feature2')
      flag_set = SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(SplitIoClient::SplitConfig.new(cache_adapter: :redis))

      expect(flag_set.get_flag_sets(['set_1'])).to eq(['feature1'])

      adapter.add_to_set('SPLITIO.flagSet.set_1', 'feature2')
      expect(flag_set.get_flag_sets(['set_1']).sort).to eq(['feature1', 'feature2'])
      sleep 0.1
      expect(flag_set.get_flag_sets(['set_2'])).to eq(['feature2'])

      adapter.delete_from_set('SPLITIO.flagSet.set_2', 'feature2')
      sleep 0.1
      expect(flag_set.get_flag_sets(['set_2'])).to eq([])

      Redis.new.flushall
    end
  end
end
