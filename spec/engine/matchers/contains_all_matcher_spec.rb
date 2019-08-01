# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ContainsAllMatcher do
  let(:local_array) { %w[a b c] }

  it 'matches' do
    expect(described_class.new('attr', %w[b], @split_logger).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[b c], @split_logger).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[a c], @split_logger).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[a b c], @split_logger).match?(attributes: { attr: local_array }))
      .to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w[a b c d], @split_logger).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[a b d], @split_logger).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[d], @split_logger).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[], @split_logger).match?(attributes: { attr: local_array }))
      .to be(false)
  end
end
