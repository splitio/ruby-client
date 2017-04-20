require 'spec_helper'

describe SplitIoClient::StartsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(v)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(va)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(val)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(valu)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(value)).match?(nil, value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(a)).match?(nil, value: value)).to be(false)
    expect(described_class.new('value', %w(o)).match?(nil, value: value)).to be(false)
    expect(described_class.new('value', %w(alue)).match?(nil, value: value)).to be(false)
    expect(described_class.new('value', %w()).match?(nil, value: value)).to be(false)
  end
end
