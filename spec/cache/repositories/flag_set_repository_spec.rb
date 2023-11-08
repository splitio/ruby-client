# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::FlagSetsRepository do
  context 'test flag set repository' do
    it 'test add/delete' do
      flag_set = SplitIoClient::Cache::Repositories::FlagSetsRepository.new []
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})

      flag_set.add_flag_set('set_1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(true)
      expect(flag_set.get_flag_set('set_1')).to eq(Set[])

      flag_set.add_flag_set('set_2')
      expect(flag_set.flag_set_exist?('set_2')).to eq(true)
      expect(flag_set.get_flag_set('set_2')).to eq(Set[])

      flag_set.remove_flag_set('set_1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(false)

      flag_set.remove_flag_set('set_2')
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})
    end

    it 'test add/delete feature flags to flag sets' do
      flag_set = SplitIoClient::Cache::Repositories::FlagSetsRepository.new []
      expect(flag_set.instance_variable_get(:@sets_feature_flag_map)).to eq({})

      flag_set.add_flag_set('set_1')
      flag_set.add_feature_flag_to_flag_set('set_1', 'feature1')
      expect(flag_set.flag_set_exist?('set_1')).to eq(true)
      expect(flag_set.get_flag_set('set_1')).to eq(Set['feature1'])

      flag_set.add_feature_flag_to_flag_set('set_1', 'feature2')
      expect(flag_set.get_flag_set('set_1')).to eq(Set['feature1', 'feature2'])

      flag_set.remove_feature_flag_from_flag_set('set_1', 'feature1')
      expect(flag_set.get_flag_set('set_1')).to eq(Set['feature2'])

      flag_set.remove_feature_flag_from_flag_set('set_1', 'feature2')
      expect(flag_set.get_flag_set('set_1')).to eq(Set[])

    end
  end
end
