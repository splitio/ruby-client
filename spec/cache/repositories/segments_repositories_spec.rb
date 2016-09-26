require 'spec_helper'

describe SplitIoClient::Cache::Repositories::SegmentsRepository do
  let(:adapter) { SplitIoClient::Cache::Adapters::MemoryAdapter.new }
  let(:repository) { described_class.new(adapter) }

  it 'removes keys' do
    repository.add_to_segment(name: 'foo', added: [1, 2, 3], removed: [])

    expect(repository.get_segment_keys('foo').keys).to eq([1, 2, 3])

    repository.send(:remove_keys, 'foo', [1, 2, 3])

    expect(repository.get_segment_keys('foo').keys).to eq([])
  end
end
