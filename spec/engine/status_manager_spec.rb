# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::StatusManager do
  subject { SplitIoClient::Engine::StatusManager }

  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new)) }

  it 'check if sdk is ready - should return false' do
    status_manager = subject.new(config)

    expect(status_manager.ready?).to eq(false)
  end

  it 'check if sdk is ready - should return true' do
    status_manager = subject.new(config)

    expect(status_manager.ready?).to eq(false)

    status_manager.ready!
    expect(status_manager.ready?).to eq(true)
  end

  it 'wait until ready - should return false' do
    status_manager = subject.new(config)

    expect { status_manager.wait_until_ready(0.5) }.to raise_error(SplitIoClient::SplitIoError, 'SDK start up timeout expired')

    status_manager.ready!
    expect { status_manager.wait_until_ready(0) }.not_to raise_error
  end
end
