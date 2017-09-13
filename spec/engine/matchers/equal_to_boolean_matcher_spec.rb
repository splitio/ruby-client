require 'spec_helper'

describe SplitIoClient::EqualToBooleanMatcher do
  it 'matches' do
    expect(described_class.new('value', true).match?(true, nil, nil, nil)).to eq(true)
    expect(described_class.new('value', true).match?('true', nil, nil, nil)).to eq(true)
    expect(described_class.new('value', true).match?('tRue', nil, nil, nil)).to eq(true)
    expect(described_class.new('value', false).match?(false, nil, nil, nil)).to eq(true)
  end

  it 'does not match' do
    expect(described_class.new('value', true).match?(false, nil, nil, nil)).to eq(false)
    expect(described_class.new('value', true).match?('false', nil, nil, nil)).to eq(false)
    expect(described_class.new('value', true).match?('whatever but true', nil, nil, nil)).to eq(false)
    expect(described_class.new('value', false).match?(true, nil, nil, nil)).to eq(false)
    expect(described_class.new('value', false).match?('', nil, nil, nil)).to eq(false)
    expect(described_class.new('value', false).match?({}, nil, nil, nil)).to eq(false)
  end
end
