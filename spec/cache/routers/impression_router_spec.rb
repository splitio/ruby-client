require 'spec_helper'

describe SplitIoClient::ImpressionRouter do
  let(:dbl) { double }
  let(:config) { SplitIoClient::SplitConfig.new(impression_listener: dbl) }
  let(:impressions) do {
      split_names: %w(ruby ruby_1),
      matching_key: 'dan',
      bucketing_key: nil,
      treatments_labels_change_numbers: {
        ruby:   { treatment: 'default', label: 'explicitly included', change_number: 1489788351672 },
        ruby_1: { treatment: 'off', label: 'in segment all', change_number: 1488927857775 }
      },
      attributes: {}
    }
  end

  it 'logs single impression' do
    expect(dbl).to receive(:log).with(foo: 'foo')

    described_class.new(config).add(foo: 'foo')
  end

  it 'logs multiple impressions' do
    expect(dbl).to receive(:log).at_least(1).times

    sleep 1

    described_class.new(config).add_bulk(impressions)
  end
end
