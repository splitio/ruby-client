# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsCountSender do
  subject { SplitIoClient::Cache::Senders::ImpressionsCountSender }

  let(:config) do
    SplitIoClient::SplitConfig.new
  end
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:impressions_api) { SplitIoClient::Api::Impressions.new('key-test', config) }
  let(:impressions_count_sender) { described_class.new(config, impression_counter, impressions_api) }

  before :each do
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:15:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:20:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:50:11'))
    impression_counter.inc('feature2', make_timestamp('2020-09-02 09:50:11'))
    impression_counter.inc('feature2', make_timestamp('2020-09-02 09:55:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 10:50:11'))
  end

  it 'post impressions count with corresponding impressions count data' do
    stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: 'ok')

    impressions_count_sender.call

    sleep 0.5

    expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
      .with(
        body:
        {
          pf:
          [
            {
              f: 'feature1',
              m: 1_599_048_000_000,
              rc: 3
            },
            {
              f: 'feature2',
              m: 1_599_048_000_000,
              rc: 2
            },
            {
              f: 'feature1',
              m: 1_599_051_600_000,
              rc: 1
            }
          ]
        }.to_json
      )).to have_been_made
  end

  it 'calls #post_impressions upon destroy' do
    expect(impressions_count_sender).to receive(:post_impressions_count).with(no_args)

    impressions_count_sender.send(:impressions_count_thread)

    sender_thread = config.threads[:impressions_count_sender]

    sender_thread.raise(SplitIoClient::SDKShutdownException)

    sender_thread.join
  end

  def make_timestamp(time)
    (Time.parse(time).to_f * 1000.0).to_i
  end
end
