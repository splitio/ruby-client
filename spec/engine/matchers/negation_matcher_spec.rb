# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::NegationMatcher do
  let(:local_array) { %w[a b c] }

  it 'does not match' do
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b c], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a c], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
  end

  it 'matches' do
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c d], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b d], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[d], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[], @default_config)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
  end

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(
        @default_config,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b], @default_config)
      )
        .string_type?).to be false
    end
  end

  context '#to_s' do
    it 'it returns not in segment all' do
      expect(described_class.new(@default_config, SplitIoClient::AllKeysMatcher.new(@default_config)).to_s)
        .to eq 'not in segment all'
    end
  end
end
