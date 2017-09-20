require 'spec_helper'

describe SplitIoClient::StartsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(v)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(va)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(val)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(valu)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(value)).match?(attributes: { value: value })).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(a)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w(o)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w(alue)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w()).match?(attributes: { value: value })).to be(false)
  end
end
