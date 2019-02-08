# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::UserDefinedSegmentMatcher do
  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(nil, nil).string_type?).to be false
    end
  end
end
