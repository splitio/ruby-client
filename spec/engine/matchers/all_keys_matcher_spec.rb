# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::AllKeysMatcher do
  context '#to_s' do
    it 'it returns in segment all' do
      expect(described_class.new(@default_config).to_s).to be 'in segment all'
    end
  end

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(@default_config).string_type?).to be false
    end
  end

  context '#equals?' do
    let(:matcher) { described_class.new(@default_config) }
    it 'is equal' do
      expect(matcher.equals?(matcher)).to be true
    end
    it 'is not equal because the object is nil' do
      expect(matcher.equals?(nil)).to be false
    end
    it 'is not equal because other type' do
      expect(matcher.equals?('string')).to be false
    end
    it 'is equal because is other instance but always return true' do
      expect(matcher.equals?(described_class.new(@default_config))).to be true
    end
  end
end
