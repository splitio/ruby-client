require 'spec_helper'

describe SplitIoClient::ContainsMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(e)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(alu)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(lue)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(alue)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(value)).match?(attributes: { value: value })).to be(true)

    expect(described_class.new('value', %w(e)).match?(value: value)).to be(true)
    expect(described_class.new('value', %w(alu)).match?(value: value)).to be(true)
    expect(described_class.new('value', %w(lue)).match?(value: value)).to be(true)
    expect(described_class.new('value', %w(alue)).match?(value: value)).to be(true)
    expect(described_class.new('value', %w(value)).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(o)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w(calue)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w()).match?(attributes: { value: value })).to be(false)

    expect(described_class.new('value', %w(o)).match?(value: value)).to be(false)
    expect(described_class.new('value', %w(calue)).match?(value: value)).to be(false)
    expect(described_class.new('value', %w()).match?(value: value)).to be(false)
  end
end
