# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Matcher do
  context '#equals?' do
    let(:matcher) { described_class.new(@default_config) }
    it 'is equal' do
      expect(matcher.equals?(matcher)).to be true
    end
    it 'is not equal because the object is nil' do
      expect(described_class.new(@default_config).equals?(nil)).to be false
    end
    it 'is not equal because other type' do
      expect(described_class.new(@default_config).equals?('string')).to be false
    end
    it 'is not equal because is other instance' do
      expect(described_class.new(@default_config).equals?(described_class.new(@default_config))).to be false
    end
  end
end
