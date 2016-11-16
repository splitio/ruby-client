require 'spec_helper'

describe SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter do
  let(:queue_size) { 3 }
  let(:adapter) { described_class.new(queue_size) }

  before do
    queue_size.times { adapter.add_to_queue('foo') }
  end

  it 'throws exception if queue size is reached' do
    expect { adapter.add_to_queue('foo') }.to raise_error(ThreadError)
  end

  it 'sets correct current_size after clear' do
    adapter.clear

    expect(adapter.instance_variable_get(:@current_size).value).to eq(0)
  end

  it 'returns correct queue size' do
    expect(adapter.instance_variable_get(:@current_size).value).to eq(queue_size)
  end
end
