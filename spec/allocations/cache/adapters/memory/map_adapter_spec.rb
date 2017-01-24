require 'spec_helper'

describe SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter do
  let(:mri_allocations) { 2 }
  let(:adapter) { described_class.new }
  let(:key) { 'foo'.freeze }
  let(:key2) { 'bar'.freeze }

  before(:each) do
    adapter
  end

  it 'initializes MapAdapter' do
    expect { adapter }.to allocate_max(mri_allocations + 1).objects
  end

  it 'initializes map' do
    expect { adapter.initialize_map(key) }.to allocate_max(mri_allocations + 1).objects
  end

  it 'adds to map' do
    adapter.initialize_map(key)

    expect { adapter.add_to_map(key, key, key) }.to allocate_max(mri_allocations).objects
  end

  it 'finds in map' do
    expect { adapter.find_in_map(key, key) }.to allocate_max(mri_allocations).objects
  end

  it 'deletes from map' do
    adapter.initialize_map(key)
    adapter.add_to_map(key, key, key)

    expect { adapter.delete_from_map(key, key) }.to allocate_max(mri_allocations).objects
  end

  it 'checks whether key is in map' do
    adapter.initialize_map(key)
    adapter.add_to_map(key, key, key)

    expect { adapter.in_map?(key, key) }.to allocate_max(mri_allocations).objects
  end

  it 'sets string' do
    expect { adapter.set_string(key, key) }.to allocate_max(mri_allocations).objects
  end

  it 'unions sets' do
    adapter.initialize_set(key)
    adapter.add_to_set(key, [key, key])
    adapter.add_to_set(key2, [key2, key2])

    expect { adapter.union_sets([key, key2]) }.to allocate_max(mri_allocations + 9).objects
  end
end
