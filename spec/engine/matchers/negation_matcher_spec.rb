# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::NegationMatcher do
  let(:local_array) { %w[a b c] }

  it 'does not match' do
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b])
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b c])
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a c])
      ).match?(attributes: { attr: local_array })
    ).to be(false)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c])
      ).match?(attributes: { attr: local_array })
    ).to be(false)
  end

  it 'matches' do
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b c d])
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[a b d])
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[d])
      ).match?(attributes: { attr: local_array })
    ).to be(true)
    expect(
      described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[])
      ).match?(attributes: { attr: local_array })
    ).to be(true)
  end

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(
        SplitIoClient::ContainsAllMatcher.new('attr', %w[b])
      )
        .string_type?).to be false
    end
  end

  context '#to_s' do
    it 'it returns not in segment all' do
      expect(described_class.new(SplitIoClient::AllKeysMatcher.new).to_s).to eq 'not in segment all'
    end
  end
end
