require 'spec_helper'
require 'securerandom'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('', logger: Logger.new('/dev/null')).client }

  let(:segments_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/segments/engine_segments.json'))) }
  let(:segments2_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/segments/engine_segments2.json'))) }

  let(:all_keys_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/all_keys_matcher.json'))) }
  let(:killed_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/killed.json'))) }
  let(:segment_deleted_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/segment_deleted_matcher.json'))) }
  let(:segment_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/segment_matcher.json'))) }
  let(:whitelist_matcher_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/engine/whitelist_matcher.json'))) }

  context '#get_treatment returns CONTROL' do
    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: all_keys_matcher_json)
    end

    it 'returns CONTROL for random id' do
      expect(subject.get_treatment('my_random_user_id', 'my_random_feaure')).to be SplitIoClient::Treatments::CONTROL
    end

    it 'returns CONTROL on null id' do
      expect(subject.get_treatment(nil, 'my_random_feaure')).to eq SplitIoClient::Treatments::CONTROL
    end

    it 'returns CONTROL on null feature' do
      expect(subject.get_treatment('my_random_user_id', nil)).to eq SplitIoClient::Treatments::CONTROL
    end
  end

  context 'all keys matcher' do
    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: all_keys_matcher_json)
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

    it 'validates the feature by bucketing_key' do
      key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

      expect(subject.get_treatment(key, 'new_feature')).to eq SplitIoClient::Treatments::ON
      impressions = subject.instance_variable_get(:@adapter).impressions.clear

      expect(impressions.first[:impressions].first.instance_variable_get(:@key)).to eq('fake_user_id_1')
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
    it "assigns keys to each of 100 treatments following a certain distribution" do
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
end
