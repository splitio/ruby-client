require 'spec_helper'

describe SplitIoClient::Cache::Stores::SDKBlocker do
  let(:config) { SplitIoClient::SplitConfig.new(block_until_ready: 1) }
  let(:sdk_blocker) { described_class.new(config) }

  it 'raises SDKBlockerTimeoutException' do
    allow(sdk_blocker).to receive(:sdk_ready?).and_return(false)

    expect { sdk_blocker.when_ready }.to raise_exception(SplitIoClient::SDKBlockerTimeoutExpiredException)
  end

  it 'does not raise SDKBlockerTimeoutException when ready' do
    allow(sdk_blocker).to receive(:sdk_ready?).and_return(true)

    expect { sdk_blocker.when_ready { 1 } }.not_to raise_exception
  end
end
