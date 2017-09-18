require 'spec_helper'

describe SplitIoClient::PartOfSetMatcher do
  let(:remote_array) { %w(a b c) }

  it 'matches' do
    # Works both with symbol and string key
    expect(described_class.new('attr', remote_array).match?(%w(a b c), nil, nil, nil)).to be(true)

    expect(described_class.new('attr', remote_array).match?(%w(a b), nil, nil, nil)).to be(true)
    expect(described_class.new('attr', remote_array).match?(%w(a), nil, nil, nil)).to be(true)
  end

  it 'does not match' do
    expect(described_class.new('attr', remote_array).match?(%w(a b c d), nil, nil, nil)).to be(false)
    expect(described_class.new('attr', remote_array).match?(%w(d), nil, nil, nil)).to be(false)
    expect(described_class.new('attr', remote_array).match?(%w(d e f), nil, nil, nil)).to be(false)
    expect(described_class.new('attr', remote_array).match?(%w(), nil, nil, nil)).to be(false)
  end
end
