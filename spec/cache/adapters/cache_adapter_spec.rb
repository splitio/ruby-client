# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Adapters::CacheAdapter do
  before :each do
    Redis.new.flushall
  end

  let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: :redis) }
  let(:redis_adapter) { config.cache_adapter }
  let(:cache_adapter) { described_class.new(config) }

  context 'string' do
    before do
      cache_adapter.set_string('foo', 'bar')
    end

    it 'returns string' do
      expect(redis_adapter).not_to receive(:string)
      expect(cache_adapter.string('foo')).to eq('bar')
    end

    it 'sets string' do
      expect(redis_adapter).not_to receive(:string)
      expect(redis_adapter).to receive(:set_string)
      cache_adapter.set_string('bar', 'baz')
      expect(cache_adapter.string('bar')).to eq('baz')
    end

    it 'sets string expired value' do
      expect(redis_adapter).to receive(:string).and_call_original
      expect(redis_adapter).to receive(:set_string).and_call_original
      cache_adapter.set_string('bar', 'baz')
      Timecop.freeze(Time.now + 10)
      expect(cache_adapter.string('bar')).to eq('baz')
      Timecop.return
    end
  end

  context 'multiple_strings' do
    before do
      cache_adapter.set_string('foo', 'bar')
      cache_adapter.set_string('baz', 'qux')
      cache_adapter.set_string('waldo', 'fred')
    end

    it 'returns cached strings' do
      expect(redis_adapter).not_to receive(:multiple_strings)
      expect(cache_adapter.multiple_strings(%w[foo baz])).to eq('foo' => 'bar', 'baz' => 'qux')
    end

    it 'returns non cached strings' do
      Timecop.freeze(Time.now + 10)
      expect(redis_adapter).to receive(:multiple_strings).and_call_original
      expect(cache_adapter.multiple_strings(%w[foo baz])).to eq('foo' => 'bar', 'baz' => 'qux')
      Timecop.return
    end

    it 'merges cached and non cached strings' do
      allow(cache_adapter).to receive(:get).with('foo').and_return('bar')
      allow(cache_adapter).to receive(:get).with('baz').and_return('qux')
      allow(cache_adapter).to receive(:get).with('waldo').and_return(nil)

      expect(redis_adapter).to receive(:multiple_strings).with(['waldo']).and_call_original
      expect(cache_adapter.multiple_strings(%w[foo baz waldo])).to eq('foo' => 'bar', 'baz' => 'qux', 'waldo' => 'fred')
    end
  end

  context 'exists?' do
    before do
      cache_adapter.set_string('foo', 'bar')
    end

    it 'returns true' do
      expect(redis_adapter).not_to receive(:exists?)
      expect(cache_adapter.exists?('foo')).to be true
    end

    it 'returns false' do
      expect(redis_adapter).to receive(:exists?).and_call_original
      expect(cache_adapter.exists?('no-key')).to be false
    end

    it 'returns true expired value' do
      Timecop.freeze(Time.now + 10)
      expect(redis_adapter).to receive(:exists?).and_call_original
      expect(cache_adapter.exists?('foo')).to be true
      Timecop.return
    end
  end

  context 'in_set?' do
    before do
      cache_adapter.add_to_set('foo', 'bar')
    end

    it 'returns true' do
      expect(redis_adapter).not_to receive(:in_set?)
      expect(cache_adapter.in_set?('foo', 'bar')).to be true
    end

    it 'returns false' do
      expect(redis_adapter).to receive(:in_set?).and_call_original
      expect(cache_adapter.in_set?('no-key', 'no-field')).to be false
    end

    it 'returns true expired value' do
      Timecop.freeze(Time.now + 10)
      expect(redis_adapter).to receive(:in_set?).and_call_original
      expect(cache_adapter.in_set?('foo', 'bar')).to be true
      Timecop.return
    end
  end

  context 'get_set' do
    before do
      cache_adapter.add_to_set('foo', 'bar')
    end

    it 'returns true' do
      expect(redis_adapter).not_to receive(:get_set)
      expect(cache_adapter.get_set('foo')).to eq ['bar']
    end

    it 'returns false' do
      expect(redis_adapter).to receive(:get_set).and_call_original
      expect(cache_adapter.get_set('no-key')).to eq []
    end

    it 'returns true expired value' do
      Timecop.freeze(Time.now + 10)
      expect(redis_adapter).to receive(:get_set).and_call_original
      expect(cache_adapter.get_set('foo')).to eq ['bar']
      Timecop.return
    end
  end
end
