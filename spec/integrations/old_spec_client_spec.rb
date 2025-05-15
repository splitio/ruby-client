# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  context 'old spec tests' do
    let(:old_spec_splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/rule_based_segments/split_old_spec.json'))) }

    it 'check new spec after last proxy timestamp expires' do
      splits_rbs = File.read(File.join(SplitIoClient.root, 'spec/test_data/rule_based_segments/rule_base_segments.json'))

      stub_request(:get, 'https://proxy-server/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return({status: 400, body: ''}, {status: 200, body: splits_rbs})
      stub_request(:get, "https://sdk.split.io/api/splitChanges?rbSince=1506703262916&s=1.3&since=1506703262916")
        .to_return(status: 200, body: '')
        stub_request(:get, 'https://proxy-server/api/splitChanges?s=1.1&since=-1')
        .to_return(status: 200, body: old_spec_splits)
      stub_request(:get, "https://proxy-server/api/splitChanges?s=1.1&since=1457726098069")
        .to_return(status: 200, body: '')
      stub_request(:post, "https://telemetry.split.io/api/v1/metrics/config")
        .to_return(status: 200, body: '')

      factory_old_spec =
        SplitIoClient::SplitFactory.new('test_api_key',
          {impressions_mode: :none,
          features_refresh_rate: 2,
          base_uri: "https://proxy-server/api",
          streaming_enabled: false})

      SplitIoClient::Api::Splits::PROXY_CHECK_INTERVAL_SECONDS = 1
      client_old_spec = factory_old_spec.client
      client_old_spec.block_until_ready
      expect(client_old_spec.get_treatment('whitelisted_user', 'whitelist_feature')).to eq('on')

      sleep 1
      split_fetcher = factory_old_spec.instance_variable_get(:@split_fetcher)
      split_fetcher.fetch_splits
      sleep 1
      expect(client_old_spec.get_treatment('bilal@split.io', 'rbs_feature_flag', {:email => 'bilal@split.io'})).to eq('on')
    end
  end
end
