# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::PartOfSetMatcher do
  let(:remote_array) { %w[a b c] }

  it 'matches' do
    # Works both with symbol and string key
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[a b c] }))
      .to be(true)
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { 'attr' => %w[a b c] }))
      .to be(true)
    expect(described_class.new(:attr, remote_array, @split_logger).match?(attributes: { attr: %w[a b c] }))
      .to be(true)
    expect(described_class.new(:attr, remote_array, @split_logger).match?(attributes: { 'attr' => %w[a b c] }))
      .to be(true)

    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[a b] }))
      .to be(true)
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[a] }))
      .to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[a b c d] }))
      .to be(false)
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[d] }))
      .to be(false)
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[d e f] }))
      .to be(false)
    expect(described_class.new('attr', remote_array, @split_logger).match?(attributes: { attr: %w[] }))
      .to be(false)
  end
end
