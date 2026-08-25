# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::ReconnectPolicy do
  subject { described_class }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), debug_enabled: true) }
  let(:status_queue) { Queue.new }
  let(:policy) { subject.new(config, status_queue) }

  describe '#record_disconnect' do
    it 'does not reset the back off for a connection that barely lived' do
      policy.connected
      policy.record_disconnect

      # BackOff.new(1, 3) starts at attempt 3, so a non-reset interval is 1 * 2**3.
      expect(policy.interval).to eq(8)
    end

    it 'resets the back off for a connection that stayed up' do
      base = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      allow(policy).to receive(:monotonic_now).and_return(base, base + described_class::MIN_UPTIME_FOR_BACKOFF_RESET + 1)
      policy.connected
      policy.record_disconnect

      # After a reset the first interval is 0, preserving fast recovery for a real success.
      expect(policy.interval).to eq(0)
    end

    it 'does not reset the back off when the monotonic clock does not advance' do
      base = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      allow(policy).to receive(:monotonic_now).and_return(base, base)
      policy.connected
      policy.record_disconnect

      # Uptime is 0, so the back off keeps growing.
      expect(policy.interval).to eq(8)
    end

    it 'keeps backing off across repeated short lived connections' do
      intervals = 4.times.map do
        policy.connected
        policy.record_disconnect
        policy.interval
      end

      expect(intervals).to eq([8, 16, 32, 64])
      expect(intervals).to all(be_positive)
    end

    it 'is a no op when there was no recorded connection' do
      policy.record_disconnect
      expect(policy.interval).to eq(8)
    end
  end

  describe '#actionable?' do
    it 'ignores a disconnect of an already disconnected stream' do
      expect(policy.actionable?(false, false)).to eq(false)
    end

    it 'acts on a disconnect of a connected stream' do
      expect(policy.actionable?(true, false)).to eq(true)
    end

    it 'allows a single reconnect and refuses a concurrent second one' do
      expect(policy.actionable?(true, true)).to eq(true)
      expect(policy.actionable?(true, true)).to eq(false)

      policy.release
      expect(policy.actionable?(true, true)).to eq(true)
    end
  end

  describe '#discard_stale_errors' do
    it 'drops queued retryable errors and preserves other statuses in order' do
      status_queue.push(SplitIoClient::Constants::PUSH_RETRYABLE_ERROR)
      status_queue.push(SplitIoClient::Constants::PUSH_CONNECTED)
      status_queue.push(SplitIoClient::Constants::PUSH_RETRYABLE_ERROR)
      status_queue.push(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)

      expect(policy.discard_stale_errors).to eq(2)
      expect(status_queue.size).to eq(2)
      expect(status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
      expect(status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)
    end

    it 'handles an empty queue' do
      expect(policy.discard_stale_errors).to eq(0)
    end
  end
end
