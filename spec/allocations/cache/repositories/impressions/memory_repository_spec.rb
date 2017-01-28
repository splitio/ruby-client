require 'spec_helper'

include SplitIoClient::Cache::Adapters

describe SplitIoClient::Cache::Repositories::Impressions::MemoryRepository do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5) }
  let(:adapter) { MemoryAdapter.new(MemoryAdapters::QueueAdapter.new(3)) }
  let(:repository) { described_class.new(adapter, config) }
  let(:key) { 'foo'.freeze }
  let(:data) { { foo: 'bar' }.freeze }

  it 'adds impression' do
    repository
    key
    data

    expect { repository.add(key, data) }.to allocate_max(3).objects
  end
end
