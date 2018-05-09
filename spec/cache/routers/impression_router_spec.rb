require 'spec_helper'

describe SplitIoClient::ImpressionRouter do
  let(:listener) { nil }
  let(:config) { SplitIoClient::SplitConfig.new(impression_listener: listener) }
  let(:impressions) do
    {
      split_names: %w(ruby ruby_1),
      matching_key: 'dan',
      bucketing_key: nil,
      treatments_labels_change_numbers: {
        ruby:   { treatment: 'default', label: 'explicitly included', change_number: 1489788351672 },
        ruby_1: { treatment: 'off', label: 'in segment all', change_number: 1488927857775 }
      },
      attributes: {}
    }
  end

  subject { described_class.new(config) }

  # Pass execution from the main thread to the subject's router_thread
  # to let the router_thread process the impression queue.
  #
  # Assumes ImpressionRouter#initialize starts router_thread and
  # Queue#pop suspends its calling thread when the receiver is empty.
  def wait_for_router_thread
    Thread.pass until config.threads[:impression_router].status != 'run'
  end

  describe '#add' do
    context 'when the config specifies an impression listener' do
      let(:listener) { double }

      it 'logs a single impression' do
        expect(listener).to receive(:log).with(foo: 'foo')

        subject.add(foo: 'foo')

        wait_for_router_thread
      end
    end

    context 'when the config does not specify an impression listener' do
      it 'ignores single impressions' do
        expect(config).not_to receive(:log_found_exception)

        subject.add(foo: 'foo')

        wait_for_router_thread
      end
    end
  end

  describe '#add_bulk' do
    context 'when the config specifies an impression listener' do
      let(:listener) { double }

      it 'logs multiple impressions' do
        expect(listener).to receive(:log).twice

        subject.add_bulk(impressions)

        wait_for_router_thread
      end
    end

    context 'when the config does not specify an impression listener' do
      it 'ignores multiple impressions' do
        expect(config).not_to receive(:log_found_exception)

        subject.add_bulk(impressions)

        wait_for_router_thread
      end
    end
  end
end
