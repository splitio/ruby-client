# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Stores::LocalhostSplitStore do
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }

  let(:split_file) do
    ['local_feature local_treatment']
  end

  before { allow(File).to receive(:open).and_return(split_file) }

  context '#initialize' do
    it 'logs warning when using old split file format' do
      described_class.new(splits_repository, config)

      expect(log.string).to include 'Localhost mode: .split mocks ' \
        'will be deprecated soon in favor of YAML files, which provide more ' \
        'targeting power. Take a look in our documentation.'
    end
  end

  context '#store_splits' do
    let(:split_file2) do
      ['local_feature local_treatment', 'local_feature2 local_treatment2']
    end

    let(:store) { described_class.new(splits_repository, config) }

    it 'stores data in the cache' do
      store.send(:store_splits)

      expect(store.splits_repository.splits.size).to eq(1)
    end

    it 'refreshes splits' do
      store.send(:store_splits)

      expect(store.splits_repository.splits.size).to eq(1)
      expect(store.splits_repository.splits['local_feature2']).to be_nil

      allow(File).to receive(:open).and_return(split_file2)

      store.send(:store_splits)

      expect(store.splits_repository.splits.size).to eq(2)
      expect(store.splits_repository.splits['local_feature2']).not_to be_nil
    end
  end
end
