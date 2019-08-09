# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ContainsMatcher do
  let(:value) { 'value' }

  it 'matches' do
    expect(described_class.new('value', %w[e], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(true)
    expect(described_class.new('value', %w[alu], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(true)
    expect(described_class.new('value', %w[lue], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(true)
    expect(described_class.new('value', %w[alue], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(true)
    expect(described_class.new('value', %w[value], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(true)

    expect(described_class.new('value', %w[e], @split_logger, @split_validator).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[alu], @split_logger, @split_validator).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[lue], @split_logger, @split_validator).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[alue], @split_logger, @split_validator).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[value], @split_logger, @split_validator).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w[o], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(false)
    expect(described_class.new('value', %w[calue], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(false)
    expect(described_class.new('value', %w[], @split_logger, @split_validator).match?(attributes: { value: value }))
      .to be(false)

    expect(described_class.new('value', %w[o], @split_logger, @split_validator).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[calue], @split_logger, @split_validator).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[], @split_logger, @split_validator).match?(value: value)).to be(false)
  end
end
