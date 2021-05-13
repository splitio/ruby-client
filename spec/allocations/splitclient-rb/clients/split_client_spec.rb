# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 10) }

  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:impressions_manager) do
    SplitIoClient::Engine::Common::ImpressionManager.new(config, impressions_repository, impression_counter)
  end
  let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
  let(:client) do
    repositories = { splits: splits_repository, segments: segments_repository, impressions: impressions_repository, events: nil }
    SplitIoClient::SplitClient.new('', repositories, nil, config, impressions_manager, evaluation_producer)
  end

  context 'control' do
    it 'allocates minimum objects' do
      expect { client.get_treatment('key', 'key') }.to allocate_max(91).objects
    end
  end
end
