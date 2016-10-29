require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('localhost').manager }

  let(:split_file) { ["local_feature local_treatment", "local_feature2 local_treatment2"] }
  

  describe "#manager get_splits returns splits from localhost mode" do
    let(:split_views) { [{:feature => "local_feature", :treatment => "local_treatment"}, {:feature => "local_feature2", :treatment => "local_treatment2"}] }
    let(:split_view) { {:feature => "local_feature" , :treatment => "local_treatment"} }

    it 'validates the calling manager.splits returns the offline data' do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:open).and_return(split_file)

      expect(subject.splits()).to eql( split_views )
      expect(subject.split("local_feature")).to eq( split_view )
    end

  end

  describe "#manager get_splitNames returns split names from localhost mode" do
    let(:split_names) { ["local_feature", "local_feature2"] }

    it 'validates the calling manager.splits returns the offline data' do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:open).and_return(split_file)

      expect(subject.splitNames()).to eql( split_names )
    end

  end
end
