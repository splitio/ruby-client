require 'spec_helper'

describe SplitIoClient::DependencyMatcher do
  let(:split_treatment) { double }

  it 'matches' do
    allow(split_treatment).to receive(:call).with({ matching_key: 'foo' }, 'foo', nil).and_return(treatment: 'yes')

    expect(described_class.new('foo', %w(on yes true)).match?('foo', split_treatment, nil)).to eq(true)
  end

  it 'does not match' do
    allow(split_treatment).to receive(:call).with({ matching_key: 'foo' }, 'foo', nil).and_return(treatment: 'no')

    expect(described_class.new('foo', %w(on yes true)).match?('foo', split_treatment, nil)).to eq(false)
  end
end
