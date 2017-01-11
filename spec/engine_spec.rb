require 'spec_helper'
require 'securerandom'

describe SplitIoClient do
  RSpec.shared_examples 'engine specs' do |cache_adapter|
    let(:config) do
      { logger: Logger.new('/dev/null'), cache_adapter: cache_adapter }
    end

    subject { SplitIoClient::SplitFactory.new('', config).client }

    let(:segments_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/segments/engine_segments.json'))) }
    let(:segments2_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/segments/engine_segments2.json'))) }

    let(:all_keys_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/all_keys_matcher.json'))) }
    let(:killed_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/killed.json'))) }
    let(:segment_deleted_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/segment_deleted_matcher.json'))) }
    let(:segment_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/segment_matcher.json'))) }
    let(:segment_matcher2_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/segment_matcher2.json'))) }
    let(:whitelist_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/whitelist_matcher.json'))) }
    let(:impressions_test_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/impressions_test.json'))) }

    before :each do
      redis = Redis.new
      redis.flushall
    end

    after :each do
      redis = Redis.new
      redis.flushall
    end

    context '#get_treatment' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      it 'returns CONTROL for random id' do
        expect(subject.get_treatment('my_random_user_id', 'my_random_feaure')).to eq SplitIoClient::Treatments::CONTROL
      end

      it 'returns CONTROL and label for random id' do
        expect(subject.get_treatment('my_random_user_id', 'my_random_feaure', nil, nil, false, true)).to eq(
          treatment: SplitIoClient::Treatments::CONTROL,
          label: SplitIoClient::Engine::Models::Label::EXCEPTION,
          change_number: nil
        )
      end

      it 'returns CONTROL on null id' do
        expect(subject.get_treatment(nil, 'my_random_feaure')).to eq SplitIoClient::Treatments::CONTROL
      end

      it 'returns CONTROL and label on null id' do
        expect(subject.get_treatment(nil, 'my_random_feaure', nil, nil, false, true)).to eq(
          treatment: SplitIoClient::Treatments::CONTROL,
          label: SplitIoClient::Engine::Models::Label::EXCEPTION,
          change_number: nil
        )
      end

      it 'returns CONTROL on null feature' do
        expect(subject.get_treatment('my_random_user_id', nil)).to eq SplitIoClient::Treatments::CONTROL
      end

      it 'returns CONTROL and label on null feature' do
        expect(subject.get_treatment('my_random_user_id', nil, nil, nil, false, true)).to eq(
          treatment: SplitIoClient::Treatments::CONTROL,
          label: SplitIoClient::Engine::Models::Label::EXCEPTION,
          change_number: nil
        )
      end
    end

    context 'all keys matcher' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      context 'producer mode' do
        let(:config) do
          { logger: Logger.new('/dev/null'), mode: :producer, cache_adapter: cache_adapter }
        end

        it 'stores splits' do
          expect(subject.instance_variable_get(:@adapter).splits_repository.splits.size).to eq(1)
        end
      end

      context 'consumer mode' do
        let(:config) do
          { logger: Logger.new('/dev/null'), mode: :consumer, cache_adapter: cache_adapter }
        end

        it 'stores splits' do
          expect(subject.instance_variable_get(:@adapter).splits_repository.splits.size).to eq(0)
        end
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq SplitIoClient::Treatments::ON
        expect(subject.get_treatment('fake_user_id_2', 'test_feature')).to eq SplitIoClient::Treatments::ON
      end
    end

    context 'in segment matcher' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: segment_matcher_json)
      end

      before do
        stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
          .to_return(status: 200, body: segments_json)
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'new_feature')).to eq SplitIoClient::Treatments::ON
      end

      it 'validates the feature is on for all ids multiple keys' do
        expect(subject.get_treatments('fake_user_id_1', ['new_feature', 'foo'])).to eq(
          new_feature: SplitIoClient::Treatments::ON, foo: SplitIoClient::Treatments::CONTROL
        )
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq SplitIoClient::Treatments::ON
        impressions = subject.instance_variable_get(:@impressions_repository).clear

        expect(impressions.first[:impressions]['key_name']).to eq('fake_user_id_1')
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq "control"
      end

      it 'validates the feature returns default treatment for non matching ids' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq "def_test"
      end

      it 'returns default treatment for active splits with a non matching id' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq "def_test"
      end
    end

    context 'get_treatments in segment matcher' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: segment_matcher2_json)
      end

      before do
        stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
          .to_return(status: 200, body: segments_json)
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatments('fake_user_id_1', ['new_feature', 'new_feature2', 'new_feature3', 'new_feature4'])).to eq(
          new_feature: SplitIoClient::Treatments::ON,
          new_feature2: SplitIoClient::Treatments::ON,
          new_feature3: SplitIoClient::Treatments::ON,
          new_feature4: SplitIoClient::Treatments::CONTROL
        )
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, ['new_feature', 'new_feature2'])).to eq(
          new_feature: SplitIoClient::Treatments::ON,
          new_feature2: SplitIoClient::Treatments::ON,
        )
        impressions = subject.instance_variable_get(:@adapter).impressions_repository.clear

        expect(impressions.first[:impressions]['key_name']).to eq('fake_user_id_1')
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, ['new_feature'])).to eq(new_feature: SplitIoClient::Treatments::CONTROL)
      end

      it 'validates the feature returns default treatment for non matching ids' do
        expect(subject.get_treatments('fake_user_id_3', ['new_feature'])).to eq(new_feature: "def_test")
      end

      it 'returns default treatment for active splits with a non matching id' do
        expect(subject.get_treatments('fake_user_id_3', ['new_feature'])).to eq(new_feature: "def_test")
      end
    end

    context 'whitelist matcher' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: whitelist_matcher_json)
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'test_whitelist')).to eq SplitIoClient::Treatments::ON
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_2', 'test_whitelist')).to eq SplitIoClient::Treatments::OFF
      end
    end

    context 'killed feature' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: killed_json)
      end

      it 'returns default treatment for killed splits' do
        expect(subject.get_treatment('fake_user_id_1', 'test_killed')).to eq "def_test"
        expect(subject.get_treatment('fake_user_id_2', 'test_killed')).to eq "def_test"
        expect(subject.get_treatment('fake_user_id_3', 'test_killed')).to eq "def_test"
      end
    end

    context 'deleted segment' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: segment_deleted_matcher_json)
      end

      before do
        stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
          .to_return(status: 200, body: segments_json)
      end

      it 'returns control for deleted splits' do
        expect(subject.get_treatment('fake_user_id_3', 'new_feature')).to eq "control"
      end
    end

    describe "splitter key assign with 100 treatments and 100K keys" do
      xit "assigns keys to each of 100 treatments following a certain distribution" do
        partitions = []
        for i in 1..100
          partitions << SplitIoClient::Partition.new({treatment: i.to_s, size: 1})
        end

        treatments = Array.new(100, 0)
        j = 100000
        k = 0.01

        for i in 0..(j-1)
          key = SecureRandom.hex(20)
          treatment = SplitIoClient::Splitter.get_treatment(key, 123, partitions)
          treatments[treatment.to_i - 1] += 1
        end

        mean = j*k
        stddev = Math.sqrt(mean * (1 - k))
        min = (mean - 4 * stddev).to_i
        max = (mean + 4 * stddev).to_i
        range = min..max

        (0..(treatments.length - 1)).each do |i|
          expect(range.cover?(treatments[i])).to be true
        end
      end
    end

    describe 'impressions' do
      let(:impressions) { subject.instance_variable_get(:@impressions_repository).clear }
      let(:formatted_impressions) { SplitIoClient::Cache::Senders::ImpressionsSender.new(nil, config, nil).send(:formatted_impressions, impressions) }

      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: impressions_test_json)
      end

      it 'returns correct impressions for get_treatments' do
        subject.get_treatments('21', ["sample_feature", "beta_feature"])
        subject.get_treatments('22', ["sample_feature", "beta_feature"])
        subject.get_treatments('23', ["sample_feature", "beta_feature"])
        subject.get_treatments('24', ["sample_feature", "beta_feature"])
        subject.get_treatments('25', ["sample_feature", "beta_feature"])
        subject.get_treatments('26', ["sample_feature", "beta_feature"])
        # Need this because we're storing impressions in the Set
        # Without sleep we may have identical impressions (including time)
        # In that case only one impression with key "26" would be stored
        sleep 0.01
        subject.get_treatments('26', ["sample_feature", "beta_feature"])

        expect(impressions.size).to eq(14)
        expect(formatted_impressions.find { |i| i[:testName] == 'sample_feature' }[:keyImpressions].size).to eq(6)
        expect(formatted_impressions.find { |i| i[:testName] == 'beta_feature' }[:keyImpressions].size).to eq(6)
      end

      context 'when impressions are disabled' do
        let(:config) do
          { logger: Logger.new('/dev/null'), cache_adapter: cache_adapter, impressions_queue_size: -1 }
        end
        let(:impressions) { subject.instance_variable_get(:@impressions_repository).clear }

        it 'works when impressions are disabled for get_treatments' do
          expect(subject.get_treatments('21', ["sample_feature", "beta_feature"])).to eq(
            {
              sample_feature: SplitIoClient::Treatments::OFF,
              beta_feature: SplitIoClient::Treatments::OFF
            }
          )

          expect(impressions).to eq([])
        end

        it 'works when impressions are disabled for get_treatment' do
          expect(subject.get_treatment('21', "sample_feature")).to eq(SplitIoClient::Treatments::OFF)

          expect(impressions).to eq([])
        end
      end
    end
  end

  include_examples 'engine specs', :memory
  include_examples 'engine specs', :redis
end
