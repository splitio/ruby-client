# frozen_string_literal: true
require 'spec_helper'
require 'set'

describe SplitIoClient::Helpers::RepositoryHelper do
  context 'test repository helper' do
    it 'with flag set filter' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new(['set_1', 'set_2'])
      flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new(['set_1', 'set_2'])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', conditions: [], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ACTIVE', conditions: [], :sets =>  ['set_3']}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ACTIVE', conditions: [], :sets =>  ['set_1']}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ARCHIVED', conditions: [], :sets =>  ['set_1']}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)
    end

    it 'without flag set filter' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', conditions: [], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split2', :status =>  'ACTIVE', conditions: [], :sets =>  ['set_3']}], -1, config, false)
      expect(feature_flag_repository.get_split('split2').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split3', :status =>  'ACTIVE', conditions: [], :sets =>  ['set_1']}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ARCHIVED', conditions: [], :sets =>  ['set_1']}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)
    end

    it 'test impressions toggle' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', conditions: [], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split1')[:impressionsDisabled]).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split2', :status =>  'ACTIVE', conditions: [], :impressionsDisabled => false, :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split2')[:impressionsDisabled]).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split2', :status =>  'ACTIVE', conditions: [], :impressionsDisabled => true, :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split2')[:impressionsDisabled]).to eq(true)
    end

    it 'test clear cache flag' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', conditions: [], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split2', :status =>  'ACTIVE', conditions: [], :sets =>  ['set_3']}], -1, config, true)
      expect(feature_flag_repository.get_split('split2').nil?).to eq(false)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)
    end

    it 'test prerequisites element' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', conditions: [], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split1')[:prerequisites]).to eq([])

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split2', :status =>  'ACTIVE', conditions: [], :prerequisites => [{:n => 'flag', :ts => ['on']}], :sets =>  []}], -1, config, false)
      expect(feature_flag_repository.get_split('split2')[:prerequisites]).to eq([{:n => 'flag', :ts => ['on']}])
    end
  end
end
