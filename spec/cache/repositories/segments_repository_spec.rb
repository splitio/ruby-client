# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::SegmentsRepository do
  context 'memory adapter' do
    let(:repository) { described_class.new(@default_config) }
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::FlagSetsRepository.new([]) }
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
    let(:split_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(@default_config, flag_sets_repository, flag_set_filter) }

    it 'removes keys' do
      repository.add_to_segment(name: 'foo', added: [1, 2, 3], removed: [])
      expect(repository.get_segment_keys('foo')).to eq([1, 2, 3])

      repository.send(:remove_keys, 'foo', [1, 2, 3])
      expect(repository.get_segment_keys('foo')).to eq([])
    end

    it 'segment names and keys count' do
      repository.add_to_segment(name: 'foo-1', added: [1, 2, 3], removed: [])
      repository.add_to_segment(name: 'foo-2', added: [1, 2, 3, 4], removed: [])
      repository.add_to_segment(name: 'foo-3', added: [], removed: [])

      split_repository.set_segment_names(['foo-1', 'foo-2', 'foo-3'])

      expect(repository.segments_count).to be(3)
      expect(repository.segment_keys_count).to be(7)
    end
  end

  context 'redis adapter' do
    let(:repository) { described_class.new(SplitIoClient::SplitConfig.new(cache_adapter: :redis)) }

    it 'removes keys' do
      repository.add_to_segment(name: 'foo', added: [1, 2, 3], removed: [])
      expect(repository.get_segment_keys('foo')).to eq(%w[1 2 3])

      repository.send(:remove_keys, 'foo', %w[1 2 3])
      expect(repository.get_segment_keys('foo')).to eq([])
    end
  end
end
