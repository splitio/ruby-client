require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('localhost') }

  let(:local_features) { ["new_feature", "test_feature"] }
  let(:data) {"new_feature,test_feature"}

  describe "#is_treatment? returns localhost mode" do
    let(:user_id) { 'my_random_user_id' }

    it 'validates the feature is on for id in local mode' do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:open).and_return(local_features)
      allow(File).to receive(:read).and_return(data)
      expect(subject.is_treatment?(user_id, 'new_feature', SplitIoClient::Treatments::ON)).to be true
    end

    it 'validates the feature is off for id in local mode' do
      allow(File).to receive(:read).and_return(data)
      expect(subject.is_treatment?(user_id, 'exclusive_feature', SplitIoClient::Treatments::CONTROL)).to be false
    end

  end
end
