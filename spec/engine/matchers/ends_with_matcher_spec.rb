# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::EndsWithMatcher do
  let(:value) { 'value' }

  it 'matches' do
    expect(described_class.new('value', %w[e], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[ue], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[lue], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[alue], @split_logger).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[value], @split_logger).match?(attributes: { value: value })).to be(true)

    expect(described_class.new(nil, %w[e], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[ue], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[lue], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[alue], @split_logger).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[value], @split_logger).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w[a], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[o], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[calue], @split_logger).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[], @split_logger).match?(attributes: { value: value })).to be(false)

    expect(described_class.new('value', %w[a], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[o], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[calue], @split_logger).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[], @split_logger).match?(value: value)).to be(false)
  end
end
