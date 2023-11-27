# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'my_impression_listener'

describe SplitIoClient, type: :client do
  RSpec.shared_examples 'SplitIoClient' do |cache_adapter|
    subject do
      SplitIoClient::SplitFactory.new('engine-spec-key',
                                      logger: Logger.new(log),
                                      cache_adapter: cache_adapter,
                                      redis_namespace: 'test',
                                      mode: @mode,
                                      features_refresh_rate: 9999,
                                      telemetry_refresh_rate: 99999,
                                      impressions_refresh_rate: 1,
                                      impression_listener: customer_impression_listener,
                                      streaming_enabled: false,
                                      impressions_mode: :debug).client
    end

    let(:customer_impression_listener) { MyImpressionListener.new }

    let(:log) { StringIO.new }

    let(:very_long_key) { 'foo' * subject.instance_variable_get(:@config).max_key_size }

    let(:segments_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/segments/engine_segments.json'))
    end
#    let(:segments2_json) do
#      File.read(File.join(SplitIoClient.root, 'spec/test_data/segments/engine_segments2.json'))
#    end
    let(:all_keys_matcher_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/all_keys_matcher.json'))
    end
    let(:configurations_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/configurations.json'))
    end
    let(:flag_sets_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/flag_sets.json'))
    end

    before do
      @mode = cache_adapter.equal?(:memory) ? :standalone : :consumer
      stub_request(:any, /https:\/\/telemetry.*/).to_return(status: 200, body: 'ok')
      stub_request(:any, /https:\/\/events.*/).to_return(status: 200, body: '')
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
      .to_return(status: 200, body: '')
    end

    before :each do
      Redis.new.flushall if @mode.equal?(:consumer)
    end

    context '#equal_to_set_matcher and get_treatment validation attributes' do
      before do
        equal_to_set_matcher_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/equal_to_set_matcher.json'))
        load_splits(equal_to_set_matcher_json, flag_sets_json)
        sleep 1
        subject.block_until_ready
      end

      it 'get_treatment_with_config returns off' do
        expect(subject.get_treatment_with_config('nicolas', 'mauro_test', nil)).to eq(
          treatment: 'off',
          config: nil
        )
        expect(subject.get_treatment_with_config('nicolas', 'mauro_test')).to eq(
          treatment: 'off',
          config: nil
        )
        expect(subject.get_treatment_with_config('nicolas', 'mauro_test', {})).to eq(
          treatment: 'off',
          config: nil
        )
        destroy_factory
      end

      it 'get_treatment returns off' do
        expect(subject.get_treatment('nicolas', 'mauro_test', nil)).to eq 'off'
        expect(subject.get_treatment('nicolas', 'mauro_test')).to eq 'off'
        expect(subject.get_treatment('nicolas', 'mauro_test', {})).to eq 'off'
      end

      it 'get_treatments returns off' do
        expect(subject.get_treatments('nicolas', ['mauro_test'], nil)).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments('nicolas', ['mauro_test'])).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments('nicolas', ['mauro_test'], {})).to eq(
          mauro_test: 'off'
        )
        destroy_factory
      end

      it 'get_treatments_by_flag_set returns off' do
        expect(subject.get_treatments_by_flag_set('nicolas', 'set_2', nil)).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments_by_flag_set('nicolas', 'set_2')).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments_by_flag_set('nicolas', 'set_2', {})).to eq(
          mauro_test: 'off'
        )
        destroy_factory
      end

      it 'get_treatments_by_flag_sets returns off' do
        expect(subject.get_treatments_by_flag_sets('nicolas', ['set_2'], nil)).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments_by_flag_sets('nicolas', ['set_2'])).to eq(
          mauro_test: 'off'
        )
        expect(subject.get_treatments_by_flag_sets('nicolas', ['set_2'], {})).to eq(
          mauro_test: 'off'
        )
        destroy_factory
      end
    end

    context '#get_treatment' do
      before do
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/).to_return(status: 200, body: '')

        load_splits(all_keys_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns CONTROL for random id' do
        expect(subject.get_treatment('random_user_id', 'my_random_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        destroy_factory
      end

      it 'returns CONTROL and label for incorrect feature name' do
        treatment = subject.get_treatment('random_user_id', 'test_featur', nil, nil, false, true)
        puts treatment
        expect(treatment).to eq(
          treatment: SplitIoClient::Engine::Models::Treatment::CONTROL,
          label: SplitIoClient::Engine::Models::Label::NOT_FOUND,
          change_number: nil
        )
        destroy_factory
      end

      it 'returns CONTROL on nil key' do
        expect(subject.get_treatment(nil, 'test_feature')).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed a nil key, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns CONTROL on empty key' do
        expect(subject.get_treatment('', 'test_feature')).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an empty matching_key, ' \
         'matching_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns CONTROL on nil matching_key' do
        expect(subject.get_treatment({ bucketing_key: nil, matching_key: nil }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string)
          .to include 'get_treatment: you passed a nil matching_key, matching_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on empty matching_key' do
        expect(subject.get_treatment({ bucketing_key: nil, matching_key: '' }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an empty matching_key, ' \
          'matching_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on longer than specified max characters matching_key' do
        expect(subject.get_treatment({ bucketing_key: nil, matching_key: very_long_key }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: matching_key is too long - ' \
          "must be #{subject.instance_variable_get(:@config).max_key_size} characters or less"
        destroy_factory
      end

      it 'logs warning when Numeric matching_key' do
        value = 123
        expect(subject.get_treatment({ bucketing_key: 'random_user_id', matching_key: value }, 'test_feature'))
          .to eq 'on'
        expect(log.string).to include "get_treatment: matching_key \"#{value}\" is not of type String, converting"
      end

      it 'returns control on nil bucketing_key' do
        expect(subject.get_treatment({ bucketing_key: nil, matching_key: 'random_user_id' }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed a nil bucketing_key, ' \
          'bucketing_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on empty bucketing_key' do
        expect(subject.get_treatment({ bucketing_key: '', matching_key: 'random_user_id' }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an empty bucketing_key, ' \
          'bucketing_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on longer than specified max characters bucketing_key' do
        expect(subject.get_treatment({ bucketing_key: very_long_key, matching_key: 'random_user_id' }, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: bucketing_key is too long - ' \
          "must be #{subject.instance_variable_get(:@config).max_key_size} characters or less"
        destroy_factory
      end

      it 'logs warning when Numeric bucketing_key' do
        value = 123
        expect(subject.get_treatment({ bucketing_key: value, matching_key: 'random_user_id' }, 'test_feature'))
          .to eq 'on'
        expect(log.string).to include "get_treatment: bucketing_key \"#{value}\" is not of type String, converting"
        destroy_factory
      end

      #TODO We will remove multiple param in the future.
      it 'returns CONTROL and label on nil key' do
        expect(subject.get_treatment(nil, 'test_feature', nil, nil, false, true)).to eq(
          treatment: SplitIoClient::Engine::Models::Treatment::CONTROL,
          label: nil,
          change_number: nil
        )
        destroy_factory
      end

      it 'returns control on empty key' do
        expect(subject.get_treatment('', 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an empty matching_key, ' \
        'matching_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on NaN key' do
        expect(subject.get_treatment(Float::NAN, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an invalid matching_key type, ' \
        'matching_key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns control on longer than specified max characters key' do
        expect(subject.get_treatment(very_long_key, 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: matching_key is too long - ' \
          "must be #{subject.instance_variable_get(:@config).max_key_size} characters or less"
        destroy_factory
      end

      it 'logs warning when Numeric key' do
        value = 123
        expect(subject.get_treatment(value, 'test_feature')).to eq 'on'
        expect(log.string).to include "get_treatment: matching_key \"#{value}\" is not of type String, converting"
        destroy_factory
      end

      it 'returns CONTROL on nil split_name' do
        expect(subject.get_treatment('random_user_id', nil)).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed a nil split_name, ' \
          'split_name must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns CONTROL on empty split_name' do
        expect(subject.get_treatment('random_user_id', '')).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        destroy_factory
      end

      it 'returns CONTROL on number split_name' do
        expect(subject.get_treatment('random_user_id', 123)).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed an invalid split_name type, ' \
          'split_name must be a non-empty String or a Symbol'
        destroy_factory
      end

      #TODO We will remove multiple param in the future.
      it 'returns CONTROL and label on nil split_name' do
        expect(subject.get_treatment('random_user_id', nil, nil, nil, false, true)).to eq(
          treatment: SplitIoClient::Engine::Models::Treatment::CONTROL,
          label: nil,
          change_number: nil
        )
        destroy_factory
      end

      it 'trims split_name and logs warning when extra whitespaces' do
        split_name = ' test_feature  '
        expect(subject.get_treatment('fake_user_id_1', split_name)).to eq 'on'
        expect(log.string).to include "get_treatment: feature_flag_name #{split_name} has extra whitespace, trimming"
        destroy_factory
      end

      it 'returns CONTROL when non Hash attributes' do
        expect(subject.get_treatment('random_user_id', 'test_feature', ["I'm an Array"]))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: attributes must be of type Hash'
        destroy_factory
      end

      it 'returns CONTROL and logs warning when ready and split does not exist' do
        expect(subject.get_treatment('random_user_id', 'non_existing_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: you passed non_existing_feature ' \
          'that does not exist in this environment, please double check what feature flags exist ' \
          'in the Split user interface'
        destroy_factory
      end

      it 'returns CONTROL with NOT_READY label when not ready' do
        allow(subject).to receive(:ready?).and_return(false)

        expect(subject.get_treatment('random_user_id', 'test_feature'))
          .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(log.string).to include 'get_treatment: the SDK is not ready, the operation cannot be executed'
        destroy_factory
      end
    end

    context '#get_treatment_with_config' do
      before do
        load_splits(configurations_json, flag_sets_json)
        subject.block_until_ready
        sleep 1
      end

      it 'returns the config' do
        split_name = 'test_feature'
        result = subject.get_treatment_with_config('fake_user_id_1', split_name)
        expect(result[:treatment]).to eq 'on'
        expect(result[:config]).to eq '{"killed":false}'
        destroy_factory
      end

      it 'returns the default treatment config on killed split' do
        split_name = 'killed_feature'
        result = subject.get_treatment_with_config('fake_user_id_1', split_name)
        expect(result[:treatment]).to eq 'off'
        expect(result[:config]).to eq '{"killed":true}'
        destroy_factory
      end

      it 'returns nil when no configs' do
        split_name = 'no_configs_feature'
        result = subject.get_treatment_with_config('fake_user_id_1', split_name)
        expect(result[:treatment]).to eq 'on'
        expect(result[:config]).to eq nil
        destroy_factory
      end

      it 'returns nil when no configs for feature' do
        split_name = 'no_configs_for_treatment_feature'
        result = subject.get_treatment_with_config('fake_user_id_1', split_name)
        expect(result[:treatment]).to eq 'on'
        expect(result[:config]).to eq nil
        destroy_factory
      end

      it 'returns control and logs the correct message on nil key' do
        split_name = 'no_configs_for_treatment_feature'
        result = subject.get_treatment_with_config(nil, split_name)
        expect(result[:treatment]).to eq SplitIoClient::Engine::Models::Treatment::CONTROL
        expect(result[:config]).to eq nil
        expect(log.string)
          .to include 'get_treatment_with_config: you passed a nil key, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'returns nil when killed and no configs for default treatment' do
        split_name = 'no_configs_killed_feature'
        result = subject.get_treatment_with_config('fake_user_id_1', split_name)
        expect(result[:treatment]).to eq 'off'
        expect(result[:config]).to eq nil
        destroy_factory
      end
    end

    context '#get_treatments' do
      before do
        load_splits(all_keys_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns empty hash on nil split_names' do
        expect(subject.get_treatments('random_user_id', nil)).to be_nil
        expect(log.string).to include 'get_treatments: feature_flag_names must be a non-empty Array'
        destroy_factory
      end

      it 'returns empty hash when no Array split_names' do
        expect(subject.get_treatments('random_user_id', Object.new)).to be_nil
        expect(log.string).to include 'get_treatments: feature_flag_names must be a non-empty Array'
        destroy_factory
      end

      it 'returns empty hash on empty array split_names' do
        expect(subject.get_treatments('random_user_id', [])).to eq({})
        expect(log.string).to include 'get_treatments: feature_flag_names must be a non-empty Array'
        destroy_factory
      end

      it 'sanitizes split_names removing repeating and nil split_names' do
        treatments = subject.get_treatments('random_user_id', ['test_feature', nil, nil, 'test_feature'])
        expect(treatments.size).to eq 1
        destroy_factory
      end

      it 'warns when non string split_names' do
        expect(subject.get_treatments('random_user_id', [Object.new, Object.new])).to eq({})
        expect(log.string).to include 'get_treatments: you passed an invalid feature_flag_name, ' \
          'flag name must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'warns when empty split_names' do
        expect(subject.get_treatments('random_user_id', [''])).to eq({})
        expect(log.string).to include 'get_treatments: you passed an empty feature_flag_name, ' \
          'flag name must be a non-empty String or a Symbol'
        destroy_factory
      end
    end

    context '#get_treatments_with_config' do
      before do
        load_splits(configurations_json, flag_sets_json)
        subject.block_until_ready
      end

      split_names = %w[test_feature no_configs_feature killed_feature]

      it 'returns the configs' do
        result = subject.get_treatments_with_config('fake_user_id_1', split_names)

        expect(result.size).to eq 3
        expect(result[:test_feature]).to eq(treatment: 'on', config: '{"killed":false}')
        expect(result[:no_configs_feature]).to eq(treatment: 'on', config: nil)
        expect(result[:killed_feature]).to eq(treatment: 'off', config: '{"killed":true}')
        destroy_factory
      end
    end

    context '#get_treatments_by_flag_set' do
      before do
        load_splits(all_keys_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns empty hash on nil split_names' do
        expect(subject.get_treatments_by_flag_set('random_user_id', nil)).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_set: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end

      it 'returns empty hash when no Array split_names' do
        expect(subject.get_treatments_by_flag_set('random_user_id', Object.new)).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_set: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end

      it 'returns empty hash on empty array split_names' do
        expect(subject.get_treatments_by_flag_set('random_user_id', [])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_set: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end

      it 'sanitizes flagset names removing repeating and nil' do
        treatments = subject.get_treatments_by_flag_set('random_user_id', ['set_1', nil, nil, 'set_1'])
        expect(treatments.size).to eq 0
        destroy_factory
      end

      it 'warns when non string flagset names' do
        expect(subject.get_treatments_by_flag_set('random_user_id', [Object.new, Object.new])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_set: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end

      it 'warns when empty flagset names' do
        expect(subject.get_treatments_by_flag_set('random_user_id', [''])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_set: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end
    end

    context '#get_treatments_by_flag_sets' do
      before do
        load_splits(all_keys_matcher_json, flag_sets_json)
        sleep 1
        subject.block_until_ready
      end

      it 'returns empty hash on nil split_names' do
        expect(subject.get_treatments_by_flag_sets('random_user_id', nil)).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_sets: FlagSets must be a non-empty list'
        destroy_factory
      end

      it 'returns empty hash when no Array split_names' do
        expect(subject.get_treatments_by_flag_sets('random_user_id', Object.new)).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_sets: FlagSets must be a non-empty list'
        destroy_factory
      end

      it 'returns empty hash on empty array split_names' do
        expect(subject.get_treatments_by_flag_sets('random_user_id', [])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_sets: FlagSets must be a non-empty list'
        destroy_factory
      end

      it 'sanitizes flagset names removing repeating and nil' do
        treatments = subject.get_treatments_by_flag_sets('random_user_id', ['set_1', nil, nil, 'set_1'])
        expect(log.string).to include 'get_treatments_by_flag_sets: you passed a nil flag set, flag set must be a non-empty String'
        expect(treatments.size).to eq 1
        destroy_factory
      end

      it 'warns when non string flagset names' do
        expect(subject.get_treatments_by_flag_sets('random_user_id', [Object.new, Object.new])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_sets: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end

      it 'warns when empty flagset names' do
        expect(subject.get_treatments_by_flag_sets('random_user_id', [''])).to eq({})
        expect(log.string).to include 'get_treatments_by_flag_sets: you passed an invalid flag set type, flag set must be a non-empty String'
        destroy_factory
      end
    end

    context '#get_treatments_with_config_by_flag_set' do
      before do
        load_splits(configurations_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns the configs' do
        result = subject.get_treatments_with_config_by_flag_set('fake_user_id_1', 'set_1')
        expect(result.size).to eq 1
        expect(result[:test_feature]).to eq(treatment: 'on', config: '{"killed":false}')
        destroy_factory
      end
    end

    context '#get_treatments_with_config_by_flag_set' do
      before do
        load_splits(configurations_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns the configs' do
        result = subject.get_treatments_with_config_by_flag_sets('fake_user_id_1', ['set_1'])
        expect(result.size).to eq 1
        expect(result[:test_feature]).to eq(treatment: 'on', config: '{"killed":false}')
        destroy_factory
      end
    end

    context 'all keys matcher' do
      before do
        load_splits(all_keys_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'
        expect(subject.get_treatment('fake_user_id_2', 'test_feature')).to eq 'on'
        destroy_factory
      end

      xit 'allocates minimum objects' do
        expect { subject.get_treatment('fake_user_id_1', 'test_feature') }.to allocate_max(283).objects
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'
        destroy_factory
      end
    end

    context 'in segment matcher' do
      before do
        load_segments(segments_json)
        segment_matcher_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_matcher.json'))
        load_splits(segment_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'new_feature')).to eq 'on'
        destroy_factory
      end

      it 'validates the feature is on for integer' do
        expect(subject.get_treatment(222, 'new_feature')).to eq 'on'
        destroy_factory
      end

      it 'validates the feature is on for all ids multiple keys' do
        expect(subject.get_treatments('fake_user_id_1', %w[new_feature foo])).to eq(
          new_feature: 'on', foo: SplitIoClient::Engine::Models::Treatment::CONTROL
        )
        destroy_factory
      end

      it "[#{cache_adapter}] validates the feature is on for all ids multiple keys for integer key" do
        expect(subject.get_treatments(222, %w[new_feature foo])).to eq(
          new_feature: 'on', foo: SplitIoClient::Engine::Models::Treatment::CONTROL
        )
        impressions = subject.instance_variable_get(:@impressions_repository).batch

        expect(impressions.size).to eq(1)
        destroy_factory
      end

      it 'validates the feature is on for all ids multiple keys for integer key' do
        expect(subject.get_treatments(222, %w[new_feature foo])).to eq(
          new_feature: 'on', foo: SplitIoClient::Engine::Models::Treatment::CONTROL
        )
        expect(subject.get_treatments({ matching_key: 222, bucketing_key: 'foo' }, %w[new_feature foo])).to eq(
          new_feature: 'on', foo: SplitIoClient::Engine::Models::Treatment::CONTROL
        )
        impressions = subject.instance_variable_get(:@impressions_repository).batch
        expect(SplitIoClient::Cache::Senders::ImpressionsFormatter
          .new(subject.instance_variable_get(:@impressions_repository))
          .call(true, impressions)
          .select { |im| im[:f] == :new_feature }[0][:i].size).to eq(2)
        destroy_factory
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).batch

        expect(impressions.first[:i][:k]).to eq('fake_user_id_1')
        destroy_factory
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq 'control'
        destroy_factory
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 222 }

        expect(subject.get_treatment(key, 'new_feature')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).batch

        expect(impressions.first[:i][:k]).to eq('222')
        destroy_factory
      end

      it 'validates the feature returns default treatment for non matching ids' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq 'def_test'
        destroy_factory
      end

      it 'returns default treatment for active splits with a non matching id' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq 'def_test'
        destroy_factory
      end
    end

    context 'get_treatments in segment matcher' do
      before do
        load_segments(segments_json)

        segment_matcher2_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_matcher2.json'))
        load_splits(segment_matcher2_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatments('fake_user_id_1', %w[new_feature new_feature2 new_feature3 new_feature4])).to eq(
          new_feature: 'on',
          new_feature2: 'on',
          new_feature3: 'on',
          new_feature4: SplitIoClient::Engine::Models::Treatment::CONTROL
        )
        destroy_factory
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, %w[new_feature new_feature2])).to eq(
          new_feature: 'on',
          new_feature2: 'on'
        )
        impressions = subject.instance_variable_get(:@impressions_repository).batch

        expect(impressions.first[:i][:k]).to eq('fake_user_id_1')
        destroy_factory
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, ['new_feature']))
          .to eq(new_feature: SplitIoClient::Engine::Models::Treatment::CONTROL)
        destroy_factory
      end

      it 'validates the feature returns default treatment for non matching ids' do
        expect(subject.get_treatments('fake_user_id_3', ['new_feature'])).to eq(new_feature: 'def_test')
        destroy_factory
      end

      it 'returns default treatment for active splits with a non matching id' do
        expect(subject.get_treatments('fake_user_id_3', ['new_feature'])).to eq(new_feature: 'def_test')
        destroy_factory
      end
    end

    context 'whitelist matcher' do
      before do
        whitelist_matcher_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/whitelist_matcher.json'))
        load_splits(whitelist_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'test_whitelist')).to eq 'on'
        destroy_factory
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_2', 'test_whitelist')).to eq 'off'
        destroy_factory
      end
    end

    context 'dependency matcher' do
      before do
        dependency_matcher_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/dependency_matcher.json'))
        load_splits(dependency_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns on treatment' do
        expect(subject.get_treatment('fake_user_id_1', 'test_dependency')).to eq 'on'
        destroy_factory
      end

      it 'produces only 1 impression' do
        expect(subject.get_treatment('fake_user_id_1', 'test_dependency')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).batch

        expect(impressions.size).to eq(1)
        destroy_factory
      end
    end

    context 'killed feature' do
      before do
        killed_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/killed.json'))
        load_splits(killed_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns default treatment for killed splits' do
        subject.block_until_ready
        expect(subject.get_treatment('fake_user_id_1', 'test_killed')).to eq 'def_test'
        expect(subject.get_treatment('fake_user_id_2', 'test_killed')).to eq 'def_test'
        expect(subject.get_treatment('fake_user_id_3', 'test_killed')).to eq 'def_test'
        destroy_factory
      end
    end

    context 'deleted segment' do
      before do
        load_segments(segments_json)

        segment_deleted_matcher_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_deleted_matcher.json'))
        load_splits(segment_deleted_matcher_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns control for deleted splits' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq 'control'
        destroy_factory
      end
    end

    describe 'splitter key assign with 100 treatments and 100K keys' do
      xit 'assigns keys to each of 100 treatments following a certain distribution' do
        partitions = []
        i = 0
        until i == 100
          partitions << SplitIoClient::Partition.new(treatment: i.to_s, size: 1)
          i += 1
        end

        treatments = Array.new(100, 0)
        j = 100_000
        k = 0.01
        i = 0
        until i == (j - 1)
          key = SecureRandom.hex(20)
          treatment = SplitIoClient::Splitter.new.get_treatment(key, 123, partitions)
          treatments[treatment.to_i - 1] += 1
          i += 1
        end

        mean = j * k
        stddev = Math.sqrt(mean * (1 - k))
        min = (mean - 4 * stddev).to_i
        max = (mean + 4 * stddev).to_i
        range = min..max
        i = 0
        until i == (treatments.length - 1)
          expect(range.cover?(treatments[i])).to be true
          i += 1
        end
        destroy_factory
      end
    end

    describe 'impressions' do
      before do
        impressions_test_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/impressions_test.json'))
        load_splits(impressions_test_json, flag_sets_json)
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/).to_return(status: 200, body: '')
      end

      it 'returns correct impressions for get_treatments checking ' do
        subject.get_treatments('26', %w[sample_feature beta_feature])
        # Need this because we're storing impressions in the Set
        # Without sleep we may have identical impressions (including time)
        # In that case only one impression with key "26" would be stored
        sleep 1

        subject.get_treatments('26', %w[sample_feature beta_feature])

        impressions = customer_impression_listener.queue

        expect(impressions.size >= 2).to be true
        destroy_factory
      end

      it 'returns correct impressions for get_treatments' do
        subject.get_treatments('21', %w[sample_feature beta_feature])
        subject.get_treatments('22', %w[sample_feature beta_feature])
        subject.get_treatments('23', %w[sample_feature beta_feature])
        subject.get_treatments('24', %w[sample_feature beta_feature])
        subject.get_treatments('25', %w[sample_feature beta_feature])
        subject.get_treatments('26', %w[sample_feature beta_feature])

        sleep 0.1
        impressions = customer_impression_listener.queue

        expect(impressions.size).to eq(12)

        expect(impressions.select { |i| i[:split_name] == :sample_feature }.size).to eq(6)
        expect(impressions.select { |i| i[:split_name] == :beta_feature }.size).to eq(6)
        destroy_factory
      end

      context 'traffic allocations' do
        before do
          traffic_allocation_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/splits_traffic_allocation.json'))
          load_splits(traffic_allocation_json, flag_sets_json)
          subject.block_until_ready
        end

        it 'returns expected treatment' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI')).to eq('off')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI')).to eq('off')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI')).to eq('off')
          destroy_factory
        end

        it 'returns expected treatment when traffic alllocation < 100' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI3')).to eq('off')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI3')).to eq('off')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI3')).to eq('off')
          destroy_factory
        end

        it 'returns expected treatment when traffic alllocation is 0' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI4')).to eq('on')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI4')).to eq('on')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI4')).to eq('on')
          destroy_factory
        end

        it 'returns "not in split" label' do
          subject.get_treatment('test', 'Traffic_Allocation_UI2')
          impressions_repository = subject.instance_variable_get(:@impressions_repository)
          expect(impressions_repository.batch[0][:i][:r]).to eq(SplitIoClient::Engine::Models::Label::NOT_IN_SPLIT)
          destroy_factory
        end
      end
    end

    context 'traffic allocation one percent' do
      before do
        traffic_allocation_one_percent_json = File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/splits_traffic_allocation_one_percent.json'))
        load_splits(traffic_allocation_one_percent_json, flag_sets_json)
        subject.block_until_ready
      end

      it 'returns expected treatment' do
        allow_any_instance_of(SplitIoClient::Splitter).to receive(:bucket).and_return(1)
        subject.block_until_ready
        expect(subject.get_treatment('test', 'Traffic_Allocation_One_Percent')).to eq('on')
        destroy_factory
      end
    end

    describe 'client destroy' do
      before do
        load_splits(all_keys_matcher_json, flag_sets_json)
      end

      it 'returns control' do
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
          .to_return(status: 200, body: all_keys_matcher_json)

        subject.block_until_ready
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'
        sleep 0.5
        destroy_factory
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'control'
      end
    end

    describe 'redis outage' do
      before do
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      it 'returns control' do
        allow(subject.instance_variable_get(:@impressions_repository))
          .to receive(:add).and_raise(Redis::CannotConnectError)
        destroy_factory
      end
    end

    describe 'events' do
      before do
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
          .to_return(status: 200, body: all_keys_matcher_json)
        subject.block_until_ready
      end

      it 'fetches and deletes events' do
        subject.track('key', 'traffic_type', 'event_type', 123)

        event = subject.instance_variable_get(:@events_repository).clear.first

        expect(event[:m]).to eq(
          s: "#{subject.instance_variable_get(:@config).language}-#{subject.instance_variable_get(:@config).version}",
          i: subject.instance_variable_get(:@config).machine_ip,
          n: subject.instance_variable_get(:@config).machine_name
        )

        expect(event[:e].reject { |e| e == :timestamp }).to eq(
          key: 'key',
          trafficTypeName: 'traffic_type',
          eventTypeId: 'event_type',
          value: 123
        )

        expect(subject.instance_variable_get(:@events_repository).clear).to eq([])
        destroy_factory
      end
    end

    context '#track' do
      before do
        stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
          .to_return(status: 200, body: all_keys_matcher_json)
        subject.block_until_ready
      end

      it 'event is not added when nil key' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(nil, 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed a nil key, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when empty key' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('', 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed an empty key, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when nil key' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(nil, 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed a nil key, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when no Integer, String or Symbol key' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(Object.new, 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed an invalid key type, key must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when longer than specified max characters key' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(very_long_key, 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include 'track: key is too long - ' \
          "must be #{subject.instance_variable_get(:@config).max_key_size} characters or less"
        destroy_factory
      end

      it 'event is added and a Warn is logged when Integer key' do
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)

        value = 123
        expect(subject.track(value, 'traffic_type', 'event_type', 123)).to be true
        expect(log.string).to include "track: key \"#{value}\" is not of type String, converting"
        destroy_factory
      end

      it 'event is not added when nil traffic_type_name' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(1, nil, 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed a nil traffic_type_name, ' \
          'traffic_type_name must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when empty string traffic_type_name' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track(1, '', 'event_type', 123)).to be false
        expect(log.string).to include 'track: you passed an empty traffic_type_name, ' \
          'traffic_type_name must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is added and a Warn is logged when capitalized traffic_type_name' do
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add).with(
          anything, 'traffic_type', anything, anything, anything, anything, anything
        )
        expect(subject.track('key', 'TRAFFIC_TYPE', 'event_type', 123)).to be true
        expect(log.string).to include 'track: traffic_type_name should be all lowercase - ' \
          'converting string to lowercase'
        destroy_factory
      end

      it 'event is not added when nil event_type' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', nil, 123)).to be false
        expect(log.string).to include 'track: you passed a nil event_type, ' \
          'event_type must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when no String or Symbol event_type' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', Object.new, 123)).to be false
        expect(log.string).to include 'track: you passed an invalid event_type type, ' \
          'event_type must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when empty event_type' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', '', 123)).to be false
        expect(log.string).to include 'track: you passed an empty event_type, ' \
          'event_type must be a non-empty String or a Symbol'
        destroy_factory
      end

      it 'event is not added when event_type does not conform with specified format' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', 'foo@bar', 123)).to be false
        expect(log.string).to include 'event_type must adhere to the regular expression ' \
          '^[a-zA-Z0-9][-_.:a-zA-Z0-9]{0,79}$. '
        destroy_factory
      end

      it 'event is not added when no Integer value' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 'non-integer')).to be false
        expect(log.string).to include 'track: value must be Numeric'
        destroy_factory
      end

      it 'event is added when nil value' do
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', nil)).to be true
        destroy_factory
      end

      it 'event is not added when non Hash properties' do
        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 123, 'not a Hash')).to be false
        expect(log.string).to include 'track: properties must be a Hash'
        destroy_factory
      end

      it 'event is not added when error calling add' do
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add).and_throw(StandardError)
        expect(subject.track('key', 'traffic_type', 'event_type', 123)).to be false
        expect(log.string).to include '[splitclient-rb] Unexpected exception in track'
        destroy_factory
      end

      it 'warns users when property count exceeds 300' do
        properties = 301.times.each_with_object({}) { |index, result| result[index.to_s] = index }

        expect(subject.send(:validate_properties, properties)).to eq [properties, 793]
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 123, properties)).to be true
        expect(log.string).to include 'Event has more than 300 properties. Some of them will be trimmed when processed'
        destroy_factory
      end

      it 'removes non String key properties' do
        properties = 10.times.each_with_object({}) do |index, result|
          index.even? ? result[index] = index : result[index.to_s] = index
        end

        expect(subject.send(:validate_properties, properties))
          .to eq [properties.select { |key, _| key.is_a?(String) }, 5]
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 123, properties)).to be true
        destroy_factory
      end

      it 'changes invalid property values to nil' do
        properties = {
          valid_property_value: 'valid',
          invalid_property_value: {}
        }

        expect(subject.send(:validate_properties, properties)).to eq [
          { valid_property_value: 'valid', invalid_property_value: nil },
          5
        ]
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 123, properties)).to be true
        expect(log.string).to include 'Property invalid_property_value is of invalid type. Setting value to nil'
        destroy_factory
      end

      it 'event is not added when properties size exceeds threshold' do
        properties = 32.times.each_with_object({}) { |index, result| result[index.to_s] = 'a' * 1000 }

        expect(subject.instance_variable_get(:@events_repository)).not_to receive(:add)
        expect(subject.track('key', 'traffic_type', 'event_type', 123, properties)).to be false
        expect(log.string).to include 'The maximum size allowed for the properties is 32768. ' \
          'Current is 33078. Event not queued'
        destroy_factory
      end

      it 'event is added and a Warn is logged when traffic type does not exist' do
        expect(subject.instance_variable_get(:@events_repository)).to receive(:add)
        allow(subject).to receive(:ready?).and_return(true)

        traffic_type_name = 'non_existing_tt_name'

        expect(subject.track('123', traffic_type_name, 'event_type', 123)).to be true
        expect(log.string).to include "track: Traffic Type #{traffic_type_name} " \
          "does not have any corresponding feature flags in this environment, make sure you're tracking " \
          'your events to a valid traffic type defined in the Split user interface'
        destroy_factory
      end
    end
  end

  context 'SDK modes' do
    let(:all_keys_matcher_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/all_keys_matcher.json'))
    end
    let(:flag_sets_json) do
      File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/flag_sets.json'))
    end

    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since.*/)
      .to_return(status: 200, body: all_keys_matcher_json)
    end

    context 'standalone mode' do
      subject do
       SplitIoClient::SplitFactory.new('engine-standalone-key',
                                        logger: Logger.new('/dev/null'),
                                        cache_adapter: :memory,
                                        mode: :standalone,
                                        features_refresh_rate: 9999,
                                        telemetry_refresh_rate: 99999,
                                        impressions_refresh_rate: 99999,
                                        streaming_enabled: false).client
      end

      it 'fetch splits' do
        subject.block_until_ready
        expect(subject.instance_variable_get(:@splits_repository).splits.size).to eq(1)
        subject.destroy
      end
    end

    context 'consumer mode' do
      before :each do
        Redis.new.flushall
      end

      after :each do
        Redis.new.flushall
      end

      subject do
        SplitIoClient::SplitFactory.new('engine-spec-redis-key',
                                        logger: Logger.new('/dev/null'),
                                        cache_adapter: :redis,
                                        redis_namespace: 'test',
                                        max_cache_size: 1,
                                        mode: :consumer,
                                        features_refresh_rate: 9999,
                                        telemetry_refresh_rate: 99999,
                                        impressions_refresh_rate: 99999,
                                        streaming_enabled: false).client
      end

      it 'does not store splits' do
        expect(subject.instance_variable_get(:@splits_repository).splits.size).to eq(0)
      end

      # config.max_cache_size set to 1 forcing cache adapter to fallback to redis
      it 'retrieves splits from redis adapter in a single mget call' do
        load_splits(all_keys_matcher_json, flag_sets_json)

        expect_any_instance_of(Redis)
          .to receive(:mget).once.and_call_original
        expect_any_instance_of(Redis)
          .not_to receive(:get)

        subject.get_treatments(222, %w[new_feature foo test_feature])
        subject.destroy
      end
    end
  end
end

describe 'with Memory Adapter' do
  it_behaves_like 'SplitIoClient', :memory
end

describe 'with Redis Adapter' do
  it_behaves_like 'SplitIoClient', :redis
end

private

def load_splits(splits_json, flag_sets_json)
  if @mode.equal?(:standalone)
    stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since.*/)
    .to_return(status: 200, body: splits_json)
  else
    add_splits_to_repository(splits_json)
    add_flag_sets_to_redis(flag_sets_json)
  end
end

def load_segments(segments_json)
  if @mode.equal?(:standalone)
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: segments_json)
  else
    add_segments_to_repository(segments_json)
  end
end

def add_splits_to_repository(splits_json)
  splits = JSON.parse(splits_json, symbolize_names: true)[:splits]

  splits_repository = subject.instance_variable_get(:@splits_repository)

  splits_repository.update(splits, [], -1)
end

def add_segments_to_repository(segments_json)
  segments_repository = subject.instance_variable_get(:@segments_repository)

  segments_repository.add_to_segment(JSON.parse(segments_json, symbolize_names: true))
end

def add_flag_sets_to_redis(flag_sets_json)
  repository = subject.instance_variable_get(:@splits_repository)
  adapter = repository.instance_variable_get(:@adapter)
  JSON.parse(flag_sets_json, symbolize_names: true).each do |key, values|
    values.each { |value|
      adapter.add_to_set("test.SPLITIO.flagSet." + key.to_s, value)
    }
  end
end

def destroy_factory
  config = subject.instance_variable_get(:@config)
  if config.cache_adapter.is_a? SplitIoClient::Cache::Adapters::RedisAdapter
    redis = config.cache_adapter.instance_variable_get(:@redis)
    redis.close
  end
  subject.destroy
end
