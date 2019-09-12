# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactoryBuilder.build('localhost').manager }

  before do
    allow(File).to receive(:exists?).and_return(true)
    allow(File).to receive(:open).and_return(split_file)
  end

  let(:split_file) { ['local_feature local_treatment', 'local_feature2 local_treatment2'] }
  let(:split_file2) { ['local_feature local_treatment2', 'local_feature2 local_treatment2'] }
  let(:split_file3) do
    ['local_feature local_treatment2', 'local_feature2 local_treatment2', 'local_feature3 local_treatment2']
  end

  let(:split_names) { %w[local_feature local_feature2] }
  let(:split_names2) { %w[local_feature local_feature2 local_feature3] }

  let(:split_view) do
    { change_number: nil,
      configs: { local_treatment: nil },
      killed: false,
      name: 'local_feature',
      traffic_type_name: nil,
      treatments: ['local_treatment'] }
  end

  let(:split_views) do
    [{ change_number: nil,
       configs: { local_treatment: nil },
       killed: false,
       name: 'local_feature',
       traffic_type_name: nil,
       treatments: ['local_treatment'] },
     { change_number: nil,
       configs: { local_treatment2: nil },
       killed: false,
       name: 'local_feature2',
       traffic_type_name: nil,
       treatments: ['local_treatment2'] }]
  end
  let(:split_views2) do
    [{ change_number: nil,
       configs: { local_treatment2: nil },
       killed: false,
       name: 'local_feature',
       traffic_type_name: nil,
       treatments: ['local_treatment2'] },
     { change_number: nil,
       configs: { local_treatment2: nil },
       killed: false,
       name: 'local_feature2',
       traffic_type_name: nil,
       treatments: ['local_treatment2'] }]
  end

  it 'validates the calling manager.splits returns the offline data' do
    expect(subject.splits).to eq(split_views)
    expect(subject.split('local_feature')).to eq(split_view)
  end

  it 'validates the calling manager.splits returns the offline data' do
    expect(subject.split_names).to eq(split_names)
  end

  context 'yaml file' do
    subject { SplitIoClient::SplitFactoryBuilder.build('localhost', split_file: split_file).manager }

    let(:split_file) { File.expand_path(File.join(File.dirname(__FILE__), '../test_data/local_treatments/split.yaml')) }

    let(:split_names) { %w[multiple_keys_feature single_key_feature no_keys_feature] }

    let(:split_views) do
      [{ change_number: nil,
         configs: {
           on: '{"desc":"this applies only to ON and only for john_doe and jane_doe. The rest will receive OFF"}',
           off: '{"desc":"this applies only to OFF treatment"}'
         },
         killed: false,
         name: 'multiple_keys_feature',
         traffic_type_name: nil,
         treatments: %w[off on] },
       { change_number: nil,
         configs: {
           on: '{"desc":"this applies only to ON and only for john_doe. The rest will receive OFF"}',
           off: '{"desc":"this applies only to OFF treatment"}'
         },
         killed: false,
         name: 'single_key_feature',
         traffic_type_name: nil,
         treatments: %w[on off] },
       { change_number: nil,
         configs: {
           off: '{"desc":"this applies only to OFF treatment"}'
         },
         killed: false,
         name: 'no_keys_feature',
         traffic_type_name: nil,
         treatments: %w[off] }]
    end

    it 'returns split_names' do
      expect(subject.split_names).to eq(split_names)
    end

    it 'returns split views with configs' do
      expect(subject.splits).to eq(split_views)
    end

    it 'returns split view with configs for specific feature' do
      expect(subject.split('single_key_feature')).to eq(split_views.find { |feat| feat[:name] == 'single_key_feature' })
    end
  end
end
