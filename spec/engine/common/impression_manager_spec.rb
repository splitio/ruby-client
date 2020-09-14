# frozen_string_literal: true

require 'spec_helper'
require 'my_impression_listener'

describe SplitIoClient::Engine::Common::ImpressionManager do
  subject { SplitIoClient::Engine::Common::ImpressionManager }

  let(:log) { StringIO.new }
  let(:impression_listener) { MyImpressionListener.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), impression_listener: impression_listener) }
  let(:ip) { config.machine_ip }
  let(:machine_name) { config.machine_name }
  let(:version) { "#{config.language}-#{config.version}" }
  let(:impression_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:expected) do
    {
      m: { s: version, i: ip, n: machine_name },
      i: {
        k: 'matching_key_test',
        b: 'bucketing_key_test',
        f: 'split_name_test',
        t: 'off',
        r: 'default label',
        c: 1_478_113_516_002,
        m: 1_478_113_516_222,
        pt: nil
      },
      attributes: {}
    }
  end

  it 'build impression' do
    impression_manager = subject.new(config, impression_repository)
    treatment = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
    params = { attributes: {}, time: 1_478_113_516_222 }
    result = impression_manager.build_impression('matching_key_test', 'bucketing_key_test', 'split_name_test', treatment, params)

    expect(result).to match(expected)
  end

  it 'track' do
    impressions = []
    impressions << expected
    impression_manager = subject.new(config, impression_repository)

    impression_manager.track(impressions)

    sleep(0.5)
    expect(impression_repository.batch.size).to eq(1)
    expect(impression_listener.size).to eq(1)
  end
end
