# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::Impressions::MemoryRepository do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5) }
  let(:adapter) { SplitIoClient::Cache::Adapters::MemoryAdapter.new(MemoryAdapters::QueueAdapter.new(3)) }
  let(:repository) { described_class.new(adapter, config) }
  let(:key) { 'foo' }
  let(:data) { { foo: 'bar' }.freeze }

  xit 'adds impression' do
    repository
    key
    data

    expect { repository.add(key, data) }.to allocate_max(3).objects
  end
end
