# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ImpressionRouter do
  let(:listener) { double }
  let(:impressions) do
    {
      split_names: %w[ruby ruby_1],
      matching_key: 'dan',
      bucketing_key: nil,
      treatments_labels_change_numbers: {
        ruby:   { treatment: 'default', label: 'explicitly included', change_number: 1_489_788_351_672 },
        ruby_1: { treatment: 'off', label: 'in segment all', change_number: 1_488_927_857_775 }
      },
      attributes: {}
    }
  end

  let(:impression_router) { described_class.new }

  # Pass execution from the main thread to the subject's router_thread
  # to let the router_thread process the impression queue.
  #
  # Assumes ImpressionRouter#initialize starts router_thread and
  # Queue#pop suspends its calling thread when the receiver is empty.
  def wait_for_router_thread
    Thread.pass until SplitIoClient.configuration.threads[:impression_router].status != 'run'
  end

  describe '#add' do
    context 'when the config specifies an impression listener' do
      it 'logs a single impression' do
        SplitIoClient.configuration.impression_listener = listener
        expect(listener).to receive(:log).with(foo: 'foo')

        impression_router.add(foo: 'foo')

        wait_for_router_thread
        expect(SplitIoClient.configuration.threads[:impression_router]).not_to be_nil
        expect(impression_router.instance_variable_get(:@queue)).not_to be_nil
      end
    end

    context 'when the config does not specify an impression listener' do
      before do
        SplitIoClient.configuration = nil
        SplitIoClient.configure
      end
      let(:listener) { nil }

      it 'ignores single impressions' do
        SplitIoClient.configuration.impression_listener = listener
        expect(SplitIoClient.configuration).not_to receive(:log_found_exception)

        impression_router.add(foo: 'foo')
        expect(SplitIoClient.configuration.threads[:impression_router]).to be_nil
        expect(impression_router.instance_variable_get(:@queue)).to be_nil
      end
    end
  end

  describe '#add_bulk' do
    context 'when the config specifies an impression listener' do
      it 'logs multiple impressions' do
        SplitIoClient.configuration.impression_listener = listener
        expect(listener).to receive(:log).twice

        impression_router.add_bulk(impressions)

        wait_for_router_thread
        expect(SplitIoClient.configuration.threads[:impression_router]).not_to be_nil
        expect(impression_router.instance_variable_get(:@queue)).not_to be_nil
      end
    end

    context 'when the config does not specify an impression listener' do
      before do
        SplitIoClient.configuration = nil
        SplitIoClient.configure
      end
      let(:listener) { nil }

      it 'ignores multiple impressions' do
        SplitIoClient.configuration.impression_listener = listener
        expect(SplitIoClient.configuration).not_to receive(:log_found_exception)

        impression_router.add_bulk(impressions)

        expect(SplitIoClient.configuration.threads[:impression_router]).to be_nil
        expect(impression_router.instance_variable_get(:@queue)).to be_nil
      end
    end
  end
end
