# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::BetweenSemverMatcher do
  let(:raw) { {
    'negate': false,
    'matcherType': 'BETWEEN_SEMVER',
    'betweenStringMatcherData': {"start": "2.1.8", "end": "2.1.11"}
} }
  let(:config) { SplitIoClient::SplitConfig.new }

  it 'initilized params' do
    matcher = described_class.new("version", raw[:betweenStringMatcherData][:start], raw[:betweenStringMatcherData][:end], config.logger, config.split_validator)
    expect(matcher.attribute).to eq("version")
    semver_start = matcher.instance_variable_get(:@semver_start)
    expect(semver_start.instance_variable_get(:@version)).to eq("2.1.8")
    semver_end = matcher.instance_variable_get(:@semver_end)
    expect(semver_end.instance_variable_get(:@version)).to eq("2.1.11")
  end

  it 'matches' do
    matcher = described_class.new("version", raw[:betweenStringMatcherData][:start], raw[:betweenStringMatcherData][:end], config.logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": "2.1.8+rc"})).to eq(true)
    expect(matcher.match?(:attributes=>{"version": "2.1.9"})).to eq(true)
    expect(matcher.match?(:attributes=>{"version": "2.1.11-rc12"})).to eq(true)
  end

  it 'does not match' do
    matcher = described_class.new("version", raw[:betweenStringMatcherData][:start], raw[:betweenStringMatcherData][:end], config.logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": "2.1.5"})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": "2.1.12-rc1"})).to eq(false)
  end

  it 'invalid attribute' do
    matcher = described_class.new("version", raw[:betweenStringMatcherData][:start], raw[:betweenStringMatcherData][:end], config.logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": 2.1})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": nil})).to eq(false)
  end

end
