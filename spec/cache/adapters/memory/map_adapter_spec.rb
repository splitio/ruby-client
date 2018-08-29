# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter do
  let(:adapter) { described_class.new }

  context 'map' do
    before do
      adapter.initialize_map('foo')
      adapter.add_to_map('foo', 'bar', 'baz')
    end

    it 'initializes map' do
      expect(adapter.instance_variable_get(:@map)['foo']).to be_a(Concurrent::Map)
    end

    it 'adds to map' do
      expect(adapter.instance_variable_get(:@map)['foo']['bar']).to eq('baz')
    end

    it 'finds in map' do
      expect(adapter.find_in_map('foo', 'bar')).to eq('baz')
    end

    it 'deletes field from map' do
      adapter.delete_from_map('foo', 'bar')

      expect(adapter.find_in_map('foo', 'bar')).to eq(nil)
    end

    it 'deletes fields from map' do
      adapter.add_to_map('foo', 'baz', 'baz')
      adapter.delete_from_map('foo', %w[bar baz])

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
      expect(adapter.get_map('foo')).to be_a(Concurrent::Map)
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

      expect(adapter.find_strings_by_prefix('foo')).to match_array(%w[foo foo2 foo3])
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
      expect(adapter.instance_variable_get(:@map)['foo']['bar']).to eq(1)
    end

    it 'adds values to set' do
      adapter.add_to_set('bar', %w[foo bar])

      expect(adapter.instance_variable_get(:@map)['bar']['foo']).to eq(1)
      expect(adapter.instance_variable_get(:@map)['bar']['bar']).to eq(1)
    end

    it 'gets all keys from set' do
      expect(adapter.get_all_from_set('foo')).to eq(['bar'])
    end

    it 'returns union sets' do
      adapter.add_to_set('bar', %w[foo bar])

      expect(adapter.union_sets(%w[foo bar])).to match_array(%w[foo bar])
    end

    it 'checks whether key exists' do
      expect(adapter.exists?('foo')).to eq(true)
    end

    it 'deletes key' do
      adapter.delete('foo')

      expect(adapter.instance_variable_get(:@map)['foo']).to eq(nil)
    end

    it 'deletes keys' do
      adapter.add_to_set('bar', 'baz')

      adapter.delete(%w[foo bar])

      expect(adapter.instance_variable_get(:@map)['foo']).to eq(nil)
      expect(adapter.instance_variable_get(:@map)['bar']).to eq(nil)
    end
  end
end
