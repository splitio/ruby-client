require 'spec_helper'

describe SplitIoClient::Cache::Stores::SDKBlocker do
  let(:config) { SplitIoClient::SplitConfig.new(block_until_ready: 1) }
  let(:sdk_blocker) { described_class.new(config) }

  xit 'raises SDKBlockerTimeoutException' do
    sdk_blocker.instance_variable_set(:@splits_thread, Thread.new { sleep })
    sdk_blocker.instance_variable_set(:@segments_thread, Thread.new { sleep })

    expect { sdk_blocker.when_ready { 1 } }.to raise_exception(SplitIoClient::SDKBlockerTimeoutExpiredException)
  end

  xit 'does not raise SDKBlockerTimeoutException when ready' do
    sdk_blocker.instance_variable_set(:@splits_ready, true)
    sdk_blocker.instance_variable_set(:@segments_ready, true)
    sdk_blocker.instance_variable_set(:@splits_thread, Thread.new {})
    sdk_blocker.instance_variable_set(:@segments_thread, Thread.new {})

    expect { sdk_blocker.when_ready { 1 } }.not_to raise_exception
  end
end
