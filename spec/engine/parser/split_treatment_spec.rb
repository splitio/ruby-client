require 'spec_helper'

include SplitIoClient

describe Engine::Parser::SplitTreatment do
  let(:adapter) { Cache::Adapters::MemoryAdapters::MapAdapter.new }
  let(:config) { SplitConfig.new }
  let(:segments_repository) { Cache::Repositories::SegmentsRepository.new(adapter, config) }
  let(:split_treatment) { described_class.new(segments_repository) }

  let(:killed_split) { { killed: true, defaultTreatment: 'default' } }
  let(:archived_split) { { status: 'ARCHIVED' } }

  it 'returns killed treatment' do
    expect(split_treatment.call('foo', killed_split)).to eq({ label: 'killed', treatment: 'default', change_number: nil})
  end

  it 'returns archived treatment' do
    expect(split_treatment.call('foo', archived_split)).to eq({ label: 'archived', treatment: Treatments::CONTROL, change_number: nil })
  end
end
