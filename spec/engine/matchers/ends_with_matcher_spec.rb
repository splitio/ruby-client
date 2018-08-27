# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::EndsWithMatcher do
  let(:value) { 'value' }

  it 'matches' do
    expect(described_class.new('value', %w[e]).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[ue]).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[lue]).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[alue]).match?(attributes: { value: value })).to be(true)
    expect(described_class.new('value', %w[value]).match?(attributes: { value: value })).to be(true)

    expect(described_class.new(nil, %w[e]).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[ue]).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[lue]).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[alue]).match?(value: value)).to be(true)
    expect(described_class.new(nil, %w[value]).match?(value: value)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %w[a]).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[o]).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[calue]).match?(attributes: { value: value })).to be(false)
    expect(described_class.new('value', %w[]).match?(attributes: { value: value })).to be(false)

    expect(described_class.new('value', %w[a]).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[o]).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[calue]).match?(value: value)).to be(false)
    expect(described_class.new('value', %w[]).match?(value: value)).to be(false)
  end
end
