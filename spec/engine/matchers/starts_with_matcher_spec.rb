# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::StartsWithMatcher do
  let(:value) { 'value' }

  it 'matches' do
    expect(described_class.new('value', %w[v], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[va], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[val], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[valu], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[value], @split_logger).match?(attributes: { value: value })).to be(true)

    expect(described_class.new('value', %w[v], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[va], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[val], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[valu], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[value], @split_logger).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w[a], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[o], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[alue], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[], @split_logger).match?(attributes: { value: value })).to be(false)

    expect(described_class.new('value', %w[a], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[o], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[alue], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[], @split_logger).match?(value: value)).to be(false)
  end
end
