require 'spec_helper'

include SplitIoClient

describe Engine::Parser::SplitTreatment do
  let(:adapter) { Cache::Adapters::MemoryAdapters::MapAdapter.new }
  let(:config) { SplitConfig.new }
  let(:segments_repository) { Cache::Repositories::SegmentsRepository.new(adapter, config) }
  let(:splits_repository) { Cache::Repositories::SplitsRepository.new(adapter, config) }
  let(:split_treatment) { described_class.new(segments_repository, splits_repository) }

  let(:killed_split) { { killed: true, defaultTreatment: 'default' } }
  let(:archived_split) { { status: 'ARCHIVED' } }
  let(:dependency_split) do
    JSON.parse(File.read(File.join(
      SplitIoClient.root, 'spec/test_data/splits/engine/dependency_matcher.json')
    ), symbolize_names: true)
  end

  it 'returns killed treatment' do
    expect(split_treatment.call('foo', killed_split)).to eq({ label: 'killed', treatment: 'default', change_number: nil})
  end

  it 'returns archived treatment' do
    expect(split_treatment.call('foo', archived_split)).to eq({ label: 'archived', treatment: SplitIoClient::Engine::Models::Treatment::CONTROL, change_number: nil })
  end

  context 'dependency matcher' do
    it 'uses cache' do
      expect(split_treatment).to receive(:match).exactly(1).times
    end
  end
end
