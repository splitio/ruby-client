require 'spec_helper'

describe SplitIoClient::ContainsAllMatcher do
  let(:local_array) { %w(a b c) }

  it 'matches' do
    expect(described_class.new('attr', %w(b)).match?(local_array, nil, nil, nil)).to be(true)
    expect(described_class.new('attr', %w(b c)).match?(local_array, nil, nil, nil)).to be(true)
    expect(described_class.new('attr', %w(a c)).match?(local_array, nil, nil, nil)).to be(true)
    expect(described_class.new('attr', %w(a b c)).match?(local_array, nil, nil, nil)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w(a b c d)).match?(local_array, nil, nil, nil)).to be(false)
    expect(described_class.new('attr', %w(a b d)).match?(local_array, nil, nil, nil)).to be(false)
    expect(described_class.new('attr', %w(d)).match?(local_array, nil, nil, nil)).to be(false)
    expect(described_class.new('attr', %w()).match?(local_array, nil, nil, nil)).to be(false)
  end
end
