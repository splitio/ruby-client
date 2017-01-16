require 'spec_helper'

describe SplitIoClient::Cache::Adapters::RedisAdapter do
  before :each do
    Redis.new.flushall
  end

  let(:adapter) { described_class.new('redis://127.0.0.1:6379/0') }

  context 'map' do
    before do
      adapter.add_to_map('foo', 'bar', 'baz')
    end

    it 'adds and finds in map' do
      expect(adapter.find_in_map('foo', 'bar')).to eq('baz')
    end

    it 'deletes field from map' do
      adapter.delete_from_map('foo', 'bar')

      expect(adapter.find_in_map('foo', 'bar')).to eq(nil)
    end

    it 'deletes fields from map' do
      adapter.add_to_map('foo', 'baz', 'baz')
      adapter.delete_from_map('foo', ['bar', 'baz'])

      expect(adapter.find_in_map('foo', 'bar')).to eq(nil)
      expect(adapter.find_in_map('foo', 'baz')).to eq(nil)
    end
    it 'checks if key is in map' do
      expect(adapter.in_map?('foo', 'bar')).to eq(true)
      expect(adapter.in_map?('foo', 'baz')).to eq(false)
    end

    it 'returns map keys' do
      expect(adapter.map_keys('foo')).to eq(['bar'])
    end

    it 'returns map' do
      expect(adapter.get_map('foo')).to eq('bar' => 'baz')
    end
  end

  context 'string' do
    before do
      adapter.set_string('foo', 'bar')
    end

    it 'returns string' do
      expect(adapter.string('foo')).to eq('bar')
    end

    it 'sets string' do
      adapter.set_string('bar', 'baz')

      expect(adapter.string('bar')).to eq('baz')
    end

    it 'finds strings by prefix' do
      adapter.set_string('foo2', 'bar')
      adapter.set_string('foo3', 'bar')
      adapter.set_string('bar', 'bar')

      expect(adapter.find_strings_by_prefix('foo')).to contain_exactly('foo', 'foo2', 'foo3')
    end

    it 'returns multiple strings' do
      adapter.set_string('foo2', 'bar')
      adapter.set_string('foo3', 'bar')
      adapter.set_string('bar', 'bar')

      keys = adapter.find_strings_by_prefix('foo')
      expect(adapter.multiple_strings(keys)).to eq(
        'foo' => 'bar',
        'foo2' => 'bar',
        'foo3' => 'bar'
      )
    end
  end

  context 'bool' do
    before do
      adapter.set_bool('foo', true)
    end

    it 'returns bool' do
      expect(adapter.bool('foo')).to eq(true)
    end

    it 'sets bool' do
      adapter.set_bool('bar', true)

      expect(adapter.bool('bar')).to eq(true)
    end
  end

  context 'set' do
    before do
      adapter.add_to_set('foo', 'bar')
    end

    it 'adds value to set' do
      expect(adapter.get_set('foo')).to eq(%w(bar))
    end

    it 'adds values to set' do
      adapter.add_to_set('bar', %w(foo bar))

      expect(adapter.get_set('bar')).to match_array(%w(foo bar))
    end

    it 'gets all keys from set' do
      expect(adapter.get_all_from_set('foo')).to eq(['bar'])
    end

    it 'returns union sets' do
      adapter.add_to_set('bar', %w(foo bar))

      expect(adapter.union_sets(['foo', 'bar'])).to match_array(%w(foo bar))
    end

    it 'checks whether key exists' do
      expect(adapter.exists?('foo')).to eq(true)
    end

    it 'deletes key' do
      adapter.delete('foo')

      expect(adapter.get_set('foo')).to eq([])
    end

    it 'deletes keys' do
      adapter.add_to_set('bar', 'baz')

      adapter.delete(['foo', 'bar'])

      expect(adapter.get_set('foo')).to eq([])
      expect(adapter.get_set('bar')).to eq([])
    end
  end
end
