require 'spec_helper'

describe SplitIoClient::ContainsMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(e)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(alu)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(lue)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(alue)).match?(nil, value: value)).to be(true)
    expect(described_class.new('value', %w(value)).match?(nil, value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(o)).match?(nil, value: value)).to be(false)
    expect(described_class.new('value', %w(calue)).match?(nil, value: value)).to be(false)
    expect(described_class.new('value', %w()).match?(nil, value: value)).to be(false)
  end
end
