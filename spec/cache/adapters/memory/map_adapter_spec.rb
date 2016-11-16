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

      expect(adapter.find_strings_by_prefix('foo')).to eq(%w(foo foo2 foo3))
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
  end
end
