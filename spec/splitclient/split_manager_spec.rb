# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:factory) { SplitIoClient::SplitFactory.new('') }
  subject { factory.manager }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits.json'))) }
  let(:segments) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/segments/engine_segments.json')))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: segments)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments)
  end

  it 'returns split_names' do
    expect(subject.split_names).to match_array(%w[test_1_ruby sample_feature])
  end

  it 'returns nil when split is nil' do
    expect(subject.split('foo')).to eq(nil)
  end

  describe 'treatments' do
    let(:splits4) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits4.json'))) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits4)
    end

    it 'returns expected treatments' do
      expect(subject.build_split_view(
        'uber_feature',
        subject.instance_variable_get(:@splits_repository).get_split('uber_feature')
      )[:treatments]).to match_array(%w[on off])
    end
  end

  describe 'client destroy' do
    before do
      factory.client.instance_variable_get(:@config).threads[:impressions_sender] = Thread.new {}
      factory.client.destroy
    end

    it 'returns empty array for #splits' do
      expect(subject.splits).to eq([])
    end

    it 'returns empty array for #split_names' do
      expect(subject.split_names).to eq([])
    end
  end
end
