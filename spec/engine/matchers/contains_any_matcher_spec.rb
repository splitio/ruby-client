require 'spec_helper'

describe SplitIoClient::ContainsAnyMatcher do
  let(:remote_array) { %w(a b c) }

  it 'matches' do
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w(a))).to be(true)
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w(a d c))).to be(true)
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w(c d e))).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', %w()).match?(nil, nil, attr: %w(a b c))).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w())).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w(d))).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, nil, attr: %w(d e f))).to be(false)
  end
end
