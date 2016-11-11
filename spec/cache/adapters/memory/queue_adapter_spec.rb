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

  it 'sets correct size_counter after clear' do
    adapter.clear

    expect(adapter.instance_variable_get(:@size_counter).value).to eq(0)
  end
end
