require 'spec_helper'

describe SplitIoClient::EndsWithMatcher do
  let(:value) { 'value'.freeze }

  it 'matches' do
    expect(described_class.new('value', %w(e)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(ue)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(lue)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(alue)).match?(value, nil, nil, nil)).to be(true)
    expect(described_class.new('value', %w(value)).match?(value, nil, nil, nil)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w(a)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w(o)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w(calue)).match?(value, nil, nil, nil)).to be(false)
    expect(described_class.new('value', %w()).match?(value, nil, nil, nil)).to be(false)
  end
end
