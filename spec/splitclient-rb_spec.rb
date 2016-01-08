require 'spec_helper'

describe SplitClient do
  subject { SplitClient::SplitIoClient.new('mykey') }

  describe '#process' do
    let(:input) { 'New String' }
    let(:output) { subject.process(input) }

    it 'converts to lowercase' do
      expect(output.downcase).to eq output
    end
  end
end