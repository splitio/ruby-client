require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactoryBuilder.build('localhost').manager }

  before do
    allow(File).to receive(:exists?).and_return(true)
    allow(File).to receive(:open).and_return(split_file)
  end

  let(:reloaded_factory) { SplitIoClient::SplitFactoryBuilder.build('localhost', reload_rate: 0.1).manager }

  let(:split_file) { ['local_feature local_treatment', 'local_feature2 local_treatment2'] }
  let(:split_file2) { ['local_feature local_treatment2', 'local_feature2 local_treatment2'] }
  let(:split_file3) { ['local_feature local_treatment2', 'local_feature2 local_treatment2', 'local_feature3 local_treatment2'] }

  let(:split_names) { ['local_feature', 'local_feature2'] }
  let(:split_names2) { ['local_feature', 'local_feature2', 'local_feature3'] }

  let(:split_view) { {:feature => 'local_feature' , :treatment => 'local_treatment'} }

  let(:split_views) { [{:feature => 'local_feature', :treatment => 'local_treatment'}, {:feature => 'local_feature2', :treatment => 'local_treatment2'}] }
  let(:split_views2) { [{:feature => 'local_feature', :treatment => 'local_treatment2'}, {:feature => 'local_feature2', :treatment => 'local_treatment2'}] }

  it 'validates the calling manager.splits returns the offline data' do
    expect(subject.splits).to eq(split_views)
    expect(subject.split('local_feature')).to eq(split_view)
  end

  it 'validates the calling manager.splits returns the offline data' do
    expect(subject.split_names).to eq(split_names)
  end

  it 'receives updated split views' do
    expect(reloaded_factory.splits).to eq(split_views)

    allow(File).to receive(:open).and_return(split_file2)

    sleep 0.2
    expect(reloaded_factory.splits).to eq(split_views2)
  end

  it 'receives updated split_names' do
    expect(reloaded_factory.split_names).to eq(split_names)

    allow(File).to receive(:open).and_return(split_file3)

    sleep 0.2
    expect(reloaded_factory.split_names).to eq(split_names2)
  end
end
