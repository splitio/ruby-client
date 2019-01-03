# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::UserDefinedSegmentMatcher do
  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(nil, nil).string_type?).to be false
    end
  end

  include_examples 'matchers equals spec', described_class.new(nil, nil)
  # context '#equals?' do
  #   let(:matcher) { }
  #   let(:other_matcher) { described_class.new(nil,nil) }
  #   it 'is equal' do
  #     expect(matcher.equals?(matcher)).to be true
  #   end
  #   it 'is not equal because the object is nil' do
  #     expect(matcher.equals?(nil)).to be false
  #   end
  #   it 'is not equal because other type' do
  #     expect(matcher.equals?('string')).to be false
  #   end
  #   it 'is not equal because is other instance of the matcher' do
  #     expect(matcher.equals?(other_matcher)).to be false
  #   end
  # end
end
