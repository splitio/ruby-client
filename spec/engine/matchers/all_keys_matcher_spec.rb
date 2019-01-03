# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::AllKeysMatcher do
  context '#to_s' do
    it 'it returns in segment all' do
      expect(described_class.new.to_s).to be 'in segment all'
    end
  end

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new.string_type?).to be false
    end
  end

  include_examples 'matchers equals spec', described_class.new
end
