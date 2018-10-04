# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  let(:map_adapter) { SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new }
  let(:queue_adapter) { SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(10) }

  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(map_adapter) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(map_adapter) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(queue_adapter) }
  let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(map_adapter) }

  let(:client) do
    SplitIoClient::SplitClient.new('', splits_repository, segments_repository,
                                   impressions_repository, metrics_repository, nil)
  end

  context 'control' do
    it 'allocates minimum objects' do
      expect { client.get_treatment('key', 'key') }.to allocate_max(91).objects
    end
  end
end
