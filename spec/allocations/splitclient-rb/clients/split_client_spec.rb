# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 10) }

  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config) }
  let(:metrics) { SplitIoClient::Metrics.new(100, metrics_repository) }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:impressions_manager) do
    SplitIoClient::Engine::Common::ImpressionManager.new(config, impressions_repository, impression_counter)
  end
  let(:client) do
    SplitIoClient::SplitClient.new('', metrics, splits_repository, segments_repository,
                                   impressions_repository, metrics_repository, nil, nil, config, impressions_manager)
  end

  context 'control' do
    it 'allocates minimum objects' do
      expect { client.get_treatment('key', 'key') }.to allocate_max(91).objects
    end
  end
end
