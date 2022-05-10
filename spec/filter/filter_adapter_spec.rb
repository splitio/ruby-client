# frozen_string_literal: true

require 'spec_helper'
require 'filter_imp_test'

describe SplitIoClient::Cache::Filter::FilterAdapter do
  subject { SplitIoClient::Cache::Filter::FilterAdapter }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:filter) { FilterTest.new }

  it 'with custom filter' do
    adapter = subject.new(config, filter)

    adapter.add('feature-1', 'custom-key-1')
    adapter.add('feature-1', 'custom-key-2')
    adapter.add('feature-1', 'custom-key-3')
    adapter.add('feature-1', 'custom-key-4')

    expect(adapter.contains?('feature-1', 'custom-key-1')).to eq(true)
    expect(adapter.contains?('feature-1', 'custom-key-2')).to eq(true)
    expect(adapter.contains?('feature-1', 'custom-key-3')).to eq(true)
    expect(adapter.contains?('feature-1', 'custom-key-4')).to eq(true)
    expect(adapter.contains?('feature-1', 'custom-key-5')).to eq(false)

    adapter.clear

    expect(adapter.contains?('feature-1', 'custom-key-1')).to eq(false)
    expect(adapter.contains?('feature-1', 'custom-key-2')).to eq(false)
    expect(adapter.contains?('feature-1', 'custom-key-3')).to eq(false)
    expect(adapter.contains?('feature-1', 'custom-key-4')).to eq(false)
  end
end
