require 'spec_helper'

describe SplitIoClient do
  let(:custom_options) { {base_uri: "http://not_default/url/",
                          connection_timeout: 1,
                          read_timeout: 2,
                          features_refresh_rate: 3,
                          segments_refresh_rate: 4,
                          metrics_refresh_rate: 5,
                          impressions_refresh_rate: 6,
                          logger: Logger.new("/dev/null"),
                          debug_enabled: true} }

  describe 'split config object values' do
    it 'sets the correct default values when no custom option is provided' do
      configs = SplitIoClient::SplitConfig.new()

      expect(configs.base_uri).to eq SplitIoClient::SplitConfig.default_base_uri.chomp('/')
      expect(configs.connection_timeout).to eq SplitIoClient::SplitConfig.default_connection_timeout
      expect(configs.read_timeout).to eq SplitIoClient::SplitConfig.default_read_timeout
      expect(configs.features_refresh_rate).to eq SplitIoClient::SplitConfig.default_features_refresh_rate
      expect(configs.segments_refresh_rate).to eq SplitIoClient::SplitConfig.default_segments_refresh_rate
      expect(configs.metrics_refresh_rate).to eq SplitIoClient::SplitConfig.default_metrics_refresh_rate
      expect(configs.impressions_refresh_rate).to eq SplitIoClient::SplitConfig.default_impressions_refresh_rate
      expect(configs.debug_enabled).to eq SplitIoClient::SplitConfig.default_debug
      expect(configs.machine_name).to eq SplitIoClient::SplitConfig.get_hostname
      expect(configs.machine_ip).to eq SplitIoClient::SplitConfig.get_ip
    end

    it 'stores and retrieves correctly the customized values' do
      configs = SplitIoClient::SplitConfig.new(custom_options)

      expect(configs.base_uri).to eq custom_options[:base_uri].chomp('/')

      expect(configs.connection_timeout).to eq custom_options[:connection_timeout]
      expect(configs.read_timeout).to eq custom_options[:read_timeout]
      expect(configs.features_refresh_rate).to eq custom_options[:features_refresh_rate]
      expect(configs.segments_refresh_rate).to eq custom_options[:segments_refresh_rate]
      expect(configs.metrics_refresh_rate).to eq custom_options[:metrics_refresh_rate]
      expect(configs.impressions_refresh_rate).to eq custom_options[:impressions_refresh_rate]
      expect(configs.debug_enabled).to eq custom_options[:debug_enabled]
    end

    it 'has the current default values for timeouts and intervals' do
      configs = SplitIoClient::SplitConfig.new()

      expect(configs.connection_timeout).to eq 5
      expect(configs.read_timeout).to eq 5
      expect(configs.features_refresh_rate).to eq 30
      expect(configs.segments_refresh_rate).to eq 60
      expect(configs.metrics_refresh_rate).to eq 60
      expect(configs.impressions_refresh_rate).to eq 60
    end
  end

end
