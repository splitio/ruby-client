# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::NegationMatcher do
  let(:local_array) { %w[a b c] }

  it 'does not match' do
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b c], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a c], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(false)
  end

  it 'matches' do
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c d], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b d], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[d], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[], @split_logger)
      ).match?(attributes: { attr: local_array })
    ).to be(true)
  end

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(
        @split_logger,
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b], @split_logger)
      )
        .string_type?).to be false
    end
  end

  context '#to_s' do
    it 'it returns not in segment all' do
      expect(described_class.new(@split_logger, SplitIoClient::AllKeysMatcher.new(@split_logger)).to_s)
        .to eq 'not in segment all'
    end
  end
end
