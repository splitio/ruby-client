require 'spec_helper'

describe SplitIoClient::EndsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(e)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(ue)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(lue)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(alue)).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w(value)).match?(attributes: { value: value })).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(a)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w(o)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w(calue)).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w()).match?(attributes: { value: value })).to be(false)
  end
end
