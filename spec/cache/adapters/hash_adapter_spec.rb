require 'spec_helper'
require 'pry'

describe SplitIoClient::Cache::Segment do
  context 'HashAdapter' do
    let(:segment) { described_class.new(SplitIoClient::Cache::Adapters::HashAdapter) }

    it 'assigns keys' do
      segment['foo'] = %w(one two)

      expect(segment['foo']).to eq(%w(one two))
    end

    it 'adds keys' do
      segment['foo'] = %w(one two)
      segment.add_keys('foo', 'three')
      expect(segment['foo']).to eq(%w(one two three))

      segment.add_keys('foo', %w(four five))
      expect(segment['foo']).to eq(%w(one two three four five))
    end

    it 'removes keys' do
      segment['foo'] = %w(one two three four five)
      segment.remove_keys('foo', 'two')
      expect(segment['foo']).to eq(%w(one three four five))

      segment.remove_keys('foo', %w(three four))
      expect(segment['foo']).to eq(%w(one five))
    end

    it 'returns true if in segment?' do
      segment['foo'] = %w(one two three four five)

      expect(segment.in?('foo', 'two')).to eq(true)
    end
  end
end
