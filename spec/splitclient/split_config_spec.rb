# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:custom_options) do
    { base_uri: 'http://not_default/url/',
      connection_timeout: 1,
      read_timeout: 2,
      features_refresh_rate: 3,
      segments_refresh_rate: 4,
      metrics_refresh_rate: 5,
      impressions_refresh_rate: 6,
      impressions_queue_size: 20,
      logger: Logger.new('/dev/null'),
      debug_enabled: true }
  end

  describe 'split config object values' do
    it 'sets the correct default values when no custom option is provided' do
      configs = SplitIoClient::SplitConfig.new
      default_ip = SplitIoClient::SplitConfig.default_ip_addresses_enabled

      expect(configs.base_uri).to eq SplitIoClient::SplitConfig.default_base_uri.chomp('/')
      expect(configs.connection_timeout).to eq SplitIoClient::SplitConfig.default_connection_timeout
      expect(configs.read_timeout).to eq SplitIoClient::SplitConfig.default_read_timeout
      expect(configs.features_refresh_rate).to eq SplitIoClient::SplitConfig.default_features_refresh_rate
      expect(configs.segments_refresh_rate).to eq SplitIoClient::SplitConfig.default_segments_refresh_rate
      expect(configs.metrics_refresh_rate).to eq SplitIoClient::SplitConfig.default_metrics_refresh_rate
      expect(configs.impressions_refresh_rate).to eq SplitIoClient::SplitConfig.default_impressions_refresh_rate
      expect(configs.impressions_queue_size).to eq SplitIoClient::SplitConfig.default_impressions_queue_size
      expect(configs.debug_enabled).to eq SplitIoClient::SplitConfig.default_debug
      expect(configs.ip_addresses_enabled).to eq default_ip
      expect(configs.machine_name).to eq SplitIoClient::SplitConfig.machine_hostname(default_ip, nil, :redis)
      expect(configs.machine_ip).to eq SplitIoClient::SplitConfig.machine_ip(default_ip, nil, :redis)
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
      expect(configs.impressions_queue_size).to eq custom_options[:impressions_queue_size]
      expect(configs.debug_enabled).to eq custom_options[:debug_enabled]
    end

    it 'has the current default values for timeouts and intervals' do
      configs = SplitIoClient::SplitConfig.new

      expect(configs.connection_timeout).to eq 5
      expect(configs.read_timeout).to eq 5
      expect(configs.features_refresh_rate).to eq 5
      expect(configs.segments_refresh_rate).to eq 60
      expect(configs.metrics_refresh_rate).to eq 60
      expect(configs.impressions_refresh_rate).to eq 60
      expect(configs.impressions_queue_size).to eq 5000
    end

    it 'set ip addresses disabled' do
      options = { ip_addresses_enabled: false }
      configs = SplitIoClient::SplitConfig.new(options)

      expect(configs.ip_addresses_enabled).to eq false
      expect(configs.machine_name).to eq ''
      expect(configs.machine_ip).to eq ''
    end

    it 'set ip addresses disabled and cache adapter is redis' do
      options = { ip_addresses_enabled: false, cache_adapter: :redis }
      configs = SplitIoClient::SplitConfig.new(options)

      expect(configs.ip_addresses_enabled).to eq false
      expect(configs.machine_name).to eq 'NA'
      expect(configs.machine_ip).to eq 'NA'
    end

    it 'set ip addresses disabled and cache adapter is memory' do
      options = { ip_addresses_enabled: false, cache_adapter: :memory }
      configs = SplitIoClient::SplitConfig.new(options)

      expect(configs.ip_addresses_enabled).to eq false
      expect(configs.machine_name).to eq ''
      expect(configs.machine_ip).to eq ''
    end

    it 'se impression mode' do
      options1 = { impressions_mode: :debug }
      configs1 = SplitIoClient::SplitConfig.new(options1)

      expect(configs1.impressions_mode).to eq(:debug)

      options2 = { impressions_mode: :optimized }
      configs2 = SplitIoClient::SplitConfig.new(options2)

      expect(configs2.impressions_mode).to eq(:optimized)

      options3 = { impressions_mode: :sarasa }
      configs3 = SplitIoClient::SplitConfig.new(options3)

      expect(configs3.impressions_mode).to eq(:optimized)
    end
  end
end
