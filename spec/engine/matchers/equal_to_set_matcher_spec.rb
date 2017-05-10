require 'spec_helper'

describe SplitIoClient::EqualToSetMatcher do
  let(:remote_array) { %w(a b c) }

  it 'matches' do
    # Works both with symbol and string key
    expect(described_class.new('attr', remote_array).match?(nil, attr: %w(a b c))).to be(true)
    expect(described_class.new('attr', remote_array).match?(nil, 'attr' => %w(a b c))).to be(true)
    expect(described_class.new(:attr, remote_array).match?(nil, attr: %w(a b c))).to be(true)
    expect(described_class.new(:attr, remote_array).match?(nil, 'attr' => %w(a b c))).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', remote_array).match?(nil, attr: %w(a b c d))).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, attr: %w(d))).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, attr: %w(d e f))).to be(false)
    expect(described_class.new('attr', remote_array).match?(nil, attr: %w())).to be(false)
  end
end
