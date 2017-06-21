require 'spec_helper'

describe SplitIoClient::EqualToBooleanMatcher do
  it 'matches' do
    expect(described_class.new('value', true).match?(nil, value: true)).to eq(true)
    expect(described_class.new('value', false).match?(nil, value: false)).to eq(true)
  end

  it 'does not match' do
    expect(described_class.new('value', true).match?(nil, value: false)).to eq(false)
    expect(described_class.new('value', false).match?(nil, value: true)).to eq(false)
  end
end
