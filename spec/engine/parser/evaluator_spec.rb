# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Parser::Evaluator do
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(@default_config) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(@default_config) }
  let(:evaluator) { described_class.new(segments_repository, splits_repository, true) }

  let(:killed_split) { { killed: true, defaultTreatment: 'default' } }
  let(:archived_split) { { status: 'ARCHIVED' } }
  let(:split_data) do
    JSON.parse(File.read(File.join(
                           SplitIoClient.root, 'spec/test_data/splits/engine/dependency_matcher.json'
                         )), symbolize_names: true)
  end

  it 'returns killed treatment' do
    expect(evaluator.call({ matching_key: 'foo' }, killed_split))
      .to eq(label: 'killed', treatment: 'default', change_number: nil, config: nil)
  end

  it 'returns archived treatment' do
    expect(evaluator.call({ matching_key: 'foo' }, archived_split))
      .to eq(label: 'archived', treatment: SplitIoClient::Engine::Models::Treatment::CONTROL,
             change_number: nil, config: nil)
  end

  context 'dependency matcher' do
    it 'uses cache' do
      allow(evaluator.instance_variable_get(:@splits_repository))
        .to receive(:get_split).and_return(split_data[:splits][0])

      expect(evaluator).to receive(:match).exactly(2).times
      evaluator.call({ bucketing_key: nil, matching_key: 'fake_user_id_1' }, split_data[:splits][0])

      evaluator.call({ bucketing_key: nil, matching_key: 'fake_user_id_1' }, split_data[:splits][1])
    end
  end
end
