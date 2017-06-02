require 'spec_helper'

describe SplitIoClient::DependencyMatcher do
  let(:split_treatment) { double }

  it 'matches' do
    allow(split_treatment).to receive(:call).with(%w(on yes true), 'foo', nil).and_return('yes')

    expect(described_class.new('foo', %w(on yes true), nil).match?('foo', split_treatment, nil)).to eq(true)
  end

  it 'does not match' do
    allow(split_treatment).to receive(:call).with(%w(on yes true), 'foo', nil).and_return('no')

    expect(described_class.new('foo', %w(on yes true), nil).match?('foo', split_treatment, nil)).to eq(false)
  end
end
