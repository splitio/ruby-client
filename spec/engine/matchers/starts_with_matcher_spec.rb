require 'spec_helper'

describe SplitIoClient::StartsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', 'v').match?(nil, value: value)).to be(true)
    expect(described_class.new('value', 'va').match?(nil, value: value)).to be(true)
    expect(described_class.new('value', 'val').match?(nil, value: value)).to be(true)
    expect(described_class.new('value', 'valu').match?(nil, value: value)).to be(true)
    expect(described_class.new('value', 'value').match?(nil, value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', 'a').match?(nil, value: value)).to be(false)
    expect(described_class.new('value', 'o').match?(nil, value: value)).to be(false)
    expect(described_class.new('value', 'alue').match?(nil, value: value)).to be(false)
    expect(described_class.new('value', '').match?(nil, value: value)).to be(false)
  end
end
