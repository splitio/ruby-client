require 'spec_helper'

describe SplitIoClient::ContainsAllMatcher do
  let(:local_array) { %w(a b c) }

  it 'matches' do
    expect(described_class.new('attr', %w(b)).match?(nil, nil, attr: local_array)).to be(true)
    expect(described_class.new('attr', %w(b c)).match?(nil, nil, attr: local_array)).to be(true)
    expect(described_class.new('attr', %w(a c)).match?(nil, nil, attr: local_array)).to be(true)
    expect(described_class.new('attr', %w(a b c)).match?(nil, nil, attr: local_array)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w(a b c d)).match?(nil, nil, attr: local_array)).to be(false)
    expect(described_class.new('attr', %w(a b d)).match?(nil, nil, attr: local_array)).to be(false)
    expect(described_class.new('attr', %w(d)).match?(nil, nil, attr: local_array)).to be(false)
    expect(described_class.new('attr', %w()).match?(nil, nil, attr: local_array)).to be(false)
  end
end
