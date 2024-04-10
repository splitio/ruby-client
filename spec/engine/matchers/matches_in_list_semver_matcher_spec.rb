# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::InListSemverMatcher do
  let(:raw) { {
    'negate': false,
    'matcherType': 'INLIST_SEMVER',
    'whitelistMatcherData': {"whitelist": ["2.1.8", "2.1.11"]}
} }
  let(:config) { SplitIoClient::SplitConfig.new }

  it 'initilized params' do
    matcher = described_class.new("version", raw[:whitelistMatcherData][:whitelist], config.split_logger, config.split_validator)
    expect(matcher.attribute).to eq("version")
    semver_list = matcher.instance_variable_get(:@semver_list)
    expect(semver_list[0].instance_variable_get(:@version)).to eq("2.1.8")
    expect(semver_list[1].instance_variable_get(:@version)).to eq("2.1.11")
  end

  it 'matches' do
    matcher = described_class.new("version", raw[:whitelistMatcherData][:whitelist], config.split_logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": "2.1.8"})).to eq(true)
    expect(matcher.match?(:attributes=>{"version": "2.1.11"})).to eq(true)
  end

  it 'does not match' do
    matcher = described_class.new("version", raw[:whitelistMatcherData][:whitelist], config.split_logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": "2.1.8+rc"})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": "2.1.7"})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": "2.1.11-rc12"})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": "2.1.8-rc1"})).to eq(false)
  end

  it 'invalid attribute' do
    matcher = described_class.new("version", raw[:whitelistMatcherData][:whitelist], config.split_logger, config.split_validator)
    expect(matcher.match?(:attributes=>{"version": 2.1})).to eq(false)
    expect(matcher.match?(:attributes=>{"version": nil})).to eq(false)
  end

end
