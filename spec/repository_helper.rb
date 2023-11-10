# frozen_string_literal: true
require 'spec_helper'
require 'set'

describe SplitIoClient::Helpers::RepositoryHelper do
  context 'test repository helper' do
    it 'with flag set filter' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new(['set_1', 'set_2'])
      flag_sets_repository = SplitIoClient::Cache::Repositories::FlagSetsRepository.new(['set_1', 'set_2'])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', :sets =>  []}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ACTIVE', :sets =>  ['set_3']}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ACTIVE', :sets =>  ['set_1']}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ARCHIVED', :sets =>  ['set_1']}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)
    end

    it 'without flag set filter' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :memory)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      flag_sets_repository = SplitIoClient::Cache::Repositories::FlagSetsRepository.new([])
      feature_flag_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(
        config,
        flag_sets_repository,
        flag_set_filter)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name => 'split1', :status =>  'ACTIVE', :sets =>  []}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split2', :status =>  'ACTIVE', :sets =>  ['set_3']}], -1, config)
      expect(feature_flag_repository.get_split('split2').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split3', :status =>  'ACTIVE', :sets =>  ['set_1']}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(false)

      SplitIoClient::Helpers::RepositoryHelper.update_feature_flag_repository(feature_flag_repository, [{:name =>  'split1', :status =>  'ARCHIVED', :sets =>  ['set_1']}], -1, config)
      expect(feature_flag_repository.get_split('split1').nil?).to eq(true)
    end
  end
end
