require 'spec_helper'

describe SplitIoClient::ContainsAllMatcher do
  let(:local_array) { %w(a b c) }

  it 'matches' do
    expect(described_class.new('attr', %w(b)).match?(attributes: { attr: local_array })).to be(true)
    expect(described_class.new('attr', %w(b c)).match?(attributes: { attr: local_array })).to be(true)
    expect(described_class.new('attr', %w(a c)).match?(attributes: { attr: local_array })).to be(true)
    expect(described_class.new('attr', %w(a b c)).match?(attributes: { attr: local_array })).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w(a b c d)).match?(attributes: { attr: local_array })).to be(false)
    expect(described_class.new('attr', %w(a b d)).match?(attributes: { attr: local_array })).to be(false)
    expect(described_class.new('attr', %w(d)).match?(attributes: { attr: local_array })).to be(false)
    expect(described_class.new('attr', %w()).match?(attributes: { attr: local_array })).to be(false)
  end
end
