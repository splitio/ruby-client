require 'spec_helper'

describe SplitIoClient::Cache::Repositories::SplitsRepository do
  let(:adapter) { SplitIoClient::Cache::Adapters::MemoryAdapter.new }
  let(:repository) { described_class.new(adapter) }

  before do
    repository.add_split(name: 'foo')
    repository.add_split(name: 'bar')
    repository.add_split(name: 'baz')
    repository.add_split(name: 'till')
  end

  it 'returns splits names' do
    expect(repository.split_names).to eq(%w(foo bar baz))
  end

  it 'returns splits data' do
    expect(repository.splits).to eq(
      'foo' => { name: 'foo' },
      'bar' => { name: 'bar' },
      'baz' => { name: 'baz' }
    )
  end
end
