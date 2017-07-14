require 'spec_helper'

describe SplitIoClient::EqualToBooleanMatcher do
  it 'matches' do
    expect(described_class.new('value', true).match?(nil, nil, nil, value: true)).to eq(true)
    expect(described_class.new('value', true).match?(nil, nil, nil, value: 'true')).to eq(true)
    expect(described_class.new('value', true).match?(nil, nil, nil, value: 'tRue')).to eq(true)
    expect(described_class.new('value', false).match?(nil, nil, nil, value: false)).to eq(true)
  end

  it 'does not match' do
    expect(described_class.new('value', true).match?(nil, nil, nil, value: false)).to eq(false)
    expect(described_class.new('value', true).match?(nil, nil, nil, value: 'false')).to eq(false)
    expect(described_class.new('value', true).match?(nil, nil, nil, value: 'whatever but true')).to eq(false)
    expect(described_class.new('value', false).match?(nil, nil, nil, value: true)).to eq(false)
  end
end
