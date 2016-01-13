require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('myrandomkey') }

  describe '#process' do
    let(:input) { 'New String' }
    let(:output) { subject.process(input) }

    it 'converts to lowercase' do
      expect(output.downcase).to eq output
    end
  end

  describe '#is_on?' do
    let(:user_id) { 'my_random_user_id' }
    let(:feature) { 'my_random_feaure' }
    let(:output) { subject.is_on?(user_id,feature)}

    it 'validates if feature is on' do
      expect(output).equal? false
    end
  end

end