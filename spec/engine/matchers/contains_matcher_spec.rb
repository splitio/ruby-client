# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ContainsMatcher do
  let(:value) { 'value' }

  it 'matches' do
    expect(described_class.new('value', %w[e], @default_config).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[alu], @default_config).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[lue], @default_config).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[alue], @default_config).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[value], @default_config).match?(attributes: { value: value })).to be(true)

    expect(described_class.new('value', %w[e], @default_config).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[alu], @default_config).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[lue], @default_config).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[alue], @default_config).match?(value: value)).to be(true)
    expect(described_class.new('value', %w[value], @default_config).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w[o], @default_config).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[calue], @default_config).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[], @default_config).match?(attributes: { value: value })).to be(false)

    expect(described_class.new('value', %w[o], @default_config).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[calue], @default_config).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[], @default_config).match?(value: value)).to be(false)
  end
end
