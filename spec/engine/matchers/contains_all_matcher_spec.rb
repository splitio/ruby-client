# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ContainsAllMatcher do
  let(:local_array) { %w[a b c] }

  it 'matches' do
    expect(described_class.new('attr', %w[b], @default_config).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[b c], @default_config).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[a c], @default_config).match?(attributes: { attr: local_array }))
      .to be(true)
    expect(described_class.new('attr', %w[a b c], @default_config).match?(attributes: { attr: local_array }))
      .to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w[a b c d], @default_config).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[a b d], @default_config).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[d], @default_config).match?(attributes: { attr: local_array }))
      .to be(false)
    expect(described_class.new('attr', %w[], @default_config).match?(attributes: { attr: local_array }))
      .to be(false)
  end
end
