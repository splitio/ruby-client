require 'spec_helper'

describe SplitIoClient::StartsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(v)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(va)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(val)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(valu)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(value)).match?(value, nil, nil, nil)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(a)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w(o)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w(alue)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w()).match?(value, nil, nil, nil)).to be(false)
  end
end
