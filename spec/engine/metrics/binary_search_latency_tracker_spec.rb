# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  it 'get_bucket' do
    result = SplitIoClient::BinarySearchLatencyTracker.get_bucket(1)
    expect(result).to be(0)

    result = SplitIoClient::BinarySearchLatencyTracker.get_bucket(1.5)
    expect(result).to be(1)

    result = SplitIoClient::BinarySearchLatencyTracker.get_bucket(2)
    expect(result).to be(2)

    result = SplitIoClient::BinarySearchLatencyTracker.get_bucket(70)
    expect(result).to be(11)

    result = SplitIoClient::BinarySearchLatencyTracker.get_bucket(8000)
    expect(result).to be(22)
  end
end
