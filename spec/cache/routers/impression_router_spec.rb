# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::ImpressionRouter do
  let(:listener) { double }
  let(:ip) { config.machine_ip }
  let(:machine_name) { config.machine_name }
  let(:version) do
    "#{config.language}-#{config.version}"
  end
  let(:impressions) do
    [
      {
        m: { s: version, i: ip, n: machine_name },
        i: {
          k: 'dan',
          b: nil,
          f: :ruby,
          t: 'default',
          r: 'explicitly included',
          c: 1_489_788_351_672,
          m: 1_478_113_516_002,
          pt: nil
        },
        attributes: {}
      },
      {
        m: { s: version, i: ip, n: machine_name },
        i: {
          k: 'dan',
          b: nil,
          f: :ruby_1,
          t: 'off',
          r: 'in segment all',
          c: 1_489_788_351_672,
          m: 1_478_113_516_002,
          pt: nil
        },
        attributes: {}
      }
    ]
  end

  let(:config) do
    SplitIoClient::SplitConfig.new(
      impression_listener: listener
    )
  end

  let(:impression_router) { described_class.new(config) }

  # Pass execution from the main thread to the subject's router_thread
  # to let the router_thread process the impression queue.
  #
  # Assumes ImpressionRouter#initialize starts router_thread and
  # Queue#pop suspends its calling thread when the receiver is empty.
  def wait_for_router_thread
    Thread.pass until config.threads[:impression_router].status != 'run'
  end

  describe '#add_bulk' do
    context 'when the config specifies an impression listener' do
      it 'logs multiple impressions' do
        expect(listener).to receive(:log).twice

        impressions.each do |imp|
          impression_router.add(imp)
        end

        wait_for_router_thread
        expect(config.threads[:impression_router]).not_to be_nil
        expect(impression_router.instance_variable_get(:@queue)).not_to be_nil
      end
    end

    context 'when the config does not specify an impression listener' do
      let(:listener) { nil }

      it 'ignores multiple impressions' do
        expect(config).not_to receive(:log_found_exception)

        impressions.each do |imp|
          impression_router.add(imp)
        end

        expect(config.threads[:impression_router]).to be_nil
        expect(impression_router.instance_variable_get(:@queue)).to be_nil
      end
    end
  end
end
