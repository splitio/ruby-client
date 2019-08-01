# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::EqualToBooleanMatcher do
  it 'matches' do
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: true })).to eq(true)
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: 'true' })).to eq(true)
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: 'tRue' })).to eq(true)
    expect(described_class.new('value', false, @split_logger).match?(attributes: { value: false })).to eq(true)
  end

  it 'does not match' do
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: false })).to eq(false)
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: 'false' })).to eq(false)
    expect(described_class.new('value', true, @split_logger).match?(attributes: { value: 'something' })).to eq(false)
    expect(described_class.new('value', false, @split_logger).match?(attributes: { value: true })).to eq(false)
    expect(described_class.new('value', false, @split_logger).match?(attributes: { value: '' })).to eq(false)
    expect(described_class.new('value', false, @split_logger).match?(attributes: { value: {} })).to eq(false)
  end
end
