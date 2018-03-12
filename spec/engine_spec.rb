require 'spec_helper'
require 'securerandom'

include SplitIoClient::Engine::Models

describe SplitIoClient do
  RSpec.shared_examples 'engine specs' do |cache_adapter|
    subject do
      SplitIoClient::SplitFactory.new('',
        logger: Logger.new('/dev/null'),
        cache_adapter: cache_adapter,
        redis_namespace: 'test'
      ).client
    end

    let(:segments_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/segments/engine_segments.json')) }
    let(:segments2_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/segments/engine_segments2.json')) }
    let(:all_keys_matcher_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/all_keys_matcher.json')) }
    let(:killed_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/killed.json')) }
    let(:segment_deleted_matcher_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_deleted_matcher.json')) }
    let(:segment_matcher_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_matcher.json')) }
    let(:segment_matcher2_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/segment_matcher2.json')) }
    let(:whitelist_matcher_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/whitelist_matcher.json')) }
    let(:dependency_matcher_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/dependency_matcher.json')) }
    let(:impressions_test_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/engine/impressions_test.json')) }
    let(:traffic_allocation_json) { File.read(File.join(SplitIoClient.root, 'spec/test_data/splits/splits_traffic_allocation.json')) }

    before :each do
      Redis.new.flushall
    end

    after :each do
      Redis.new.flushall
    end

    context '#get_treatment' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      it 'returns CONTROL for random id' do
        expect(subject.get_treatment('my_random_user_id', 'my_random_feaure')).to eq Treatment::CONTROL
      end

      it 'returns CONTROL and label for random id' do
        expect(subject.get_treatment('my_random_user_id', 'my_random_feaure', nil, nil, false, true)).to eq(
          treatment: Treatment::CONTROL,
          label: Label::DEFINITION_NOT_FOUND,
          change_number: nil
        )
      end

      it 'returns CONTROL on null id' do
        expect(subject.get_treatment(nil, 'my_random_feaure')).to eq Treatment::CONTROL
      end

      it 'returns CONTROL and label on null id' do
        expect(subject.get_treatment(nil, 'my_random_feaure', nil, nil, false, true)).to eq(
          treatment: Treatment::CONTROL,
          label: Label::DEFINITION_NOT_FOUND,
          change_number: nil
        )
      end

      it 'returns CONTROL on null feature' do
        expect(subject.get_treatment('my_random_user_id', nil)).to eq Treatment::CONTROL
      end

      it 'returns CONTROL and label on null feature' do
        expect(subject.get_treatment('my_random_user_id', nil, nil, nil, false, true)).to eq(
          treatment: Treatment::CONTROL,
          label: Label::DEFINITION_NOT_FOUND,
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
        subject do
          SplitIoClient::SplitFactory.new('',
            logger: Logger.new('/dev/null'),
            cache_adapter: cache_adapter,
            redis_namespace: 'test',
            mode: :producer
          ).client
        end

        it 'stores splits' do
          expect(subject.instance_variable_get(:@adapter).splits_repository.splits.size).to eq(1)
        end
      end

      context 'consumer mode' do
        subject do
          SplitIoClient::SplitFactory.new('',
            logger: Logger.new('/dev/null'),
            cache_adapter: cache_adapter,
            redis_namespace: 'test',
            mode: :consumer
          ).client
        end

        it 'stores splits' do
          expect(subject.instance_variable_get(:@adapter).splits_repository.splits.size).to eq(0)
        end
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'
        expect(subject.get_treatment('fake_user_id_2', 'test_feature')).to eq 'on'
      end

      xit 'allocates minimum objects' do
        expect { subject.get_treatment('fake_user_id_1', 'test_feature') }.to allocate_max(283).objects
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'
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
        expect(subject.get_treatment('fake_user_id_1', 'new_feature')).to eq 'on'
      end

      it 'validates the feature is on for integer' do
        expect(subject.get_treatment(222, 'new_feature')).to eq 'on'
      end

      it 'validates the feature is on for all ids multiple keys' do
        expect(subject.get_treatments('fake_user_id_1', ['new_feature', 'foo'])).to eq(
          new_feature: 'on', foo: Treatment::CONTROL
        )
      end

      it "[#{cache_adapter}] validates the feature is on for all ids multiple keys for integer key" do
        expect(subject.get_treatments(222, ['new_feature', 'foo'])).to eq(
          new_feature: 'on', foo: Treatment::CONTROL
        )
        impressions = subject.instance_variable_get(:@impressions_repository).clear
        expect(impressions.collect { |i| i[:feature] }).to match_array %i(foo new_feature)
      end

      it 'validates the feature is on for all ids multiple keys for integer key' do
        expect(subject.get_treatments(222, ['new_feature', 'foo'])).to eq(
          new_feature: 'on', foo: Treatment::CONTROL
        )
        expect(subject.get_treatments({ matching_key: 222, bucketing_key: 'foo' }, ['new_feature', 'foo'])).to eq(
          new_feature: 'on', foo: Treatment::CONTROL
        )
        impressions = subject.instance_variable_get(:@impressions_repository).clear
        expect(ImpressionsFormatter
          .new(subject.instance_variable_get(:@impressions_repository))
          .call(impressions)
          .select { |im| im[:testName] == :new_feature }[0][:keyImpressions].size
        ).to eq(2)
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).clear

        expect(impressions.first[:impressions]['keyName']).to eq('fake_user_id_1')
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatment(key, 'new_feature')).to eq "control"
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 222 }

        expect(subject.get_treatment(key, 'new_feature')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).clear

        expect(impressions.first[:impressions]['keyName']).to eq('222')
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
          new_feature: 'on',
          new_feature2: 'on',
          new_feature3: 'on',
          new_feature4: Treatment::CONTROL
        )
      end

      it 'validates the feature by bucketing_key' do
        key = { bucketing_key: 'bucketing_key', matching_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, ['new_feature', 'new_feature2'])).to eq(
          new_feature: 'on',
          new_feature2: 'on',
        )
        impressions = subject.instance_variable_get(:@adapter).impressions_repository.clear

        expect(impressions.first[:impressions]['keyName']).to eq('fake_user_id_1')
      end

      it 'validates the feature by bucketing_key for nil matching_key' do
        key = { bucketing_key: 'fake_user_id_1' }

        expect(subject.get_treatments(key, ['new_feature'])).to eq(new_feature: Treatment::CONTROL)
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
        expect(subject.get_treatment('fake_user_id_1', 'test_whitelist')).to eq 'on'
      end

      it 'validates the feature is on for all ids' do
        expect(subject.get_treatment('fake_user_id_2', 'test_whitelist')).to eq 'off'
      end
    end

    context 'dependency matcher' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: dependency_matcher_json)
      end

      it 'returns on treatment' do
        expect(subject.get_treatment('fake_user_id_1', 'test_dependency')).to eq 'on'
      end

      it 'produces only 1 impression' do
        expect(subject.get_treatment('fake_user_id_1', 'test_dependency')).to eq 'on'
        impressions = subject.instance_variable_get(:@impressions_repository).clear

        expect(impressions.size).to eq(1)
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
          treatment = SplitIoClient::Splitter.new.get_treatment(key, 123, partitions)
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
      let(:formatted_impressions) do
        SplitIoClient::Cache::Senders::ImpressionsSender
          .new(nil, {}, nil)
          .send(:formatted_impressions, impressions)
      end

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

        expect(formatted_impressions.find { |i| i[:testName] == :sample_feature }[:keyImpressions].size).to eq(6)
        expect(formatted_impressions.find { |i| i[:testName] == :beta_feature }[:keyImpressions].size).to eq(6)
      end

      context 'when impressions are disabled' do
        subject do
          SplitIoClient::SplitFactory.new('',
            logger: Logger.new('/dev/null'),
            cache_adapter: cache_adapter,
            redis_namespace: 'test',
            impressions_queue_size: -1
          ).client
        end
        let(:impressions) { subject.instance_variable_get(:@impressions_repository).clear }

        it 'works when impressions are disabled for get_treatments' do
          expect(subject.get_treatments('21', ["sample_feature", "beta_feature"])).to eq(
            {
              sample_feature: 'off',
              beta_feature: 'off'
            }
          )

          expect(impressions).to eq([])
        end

        it 'works when impressions are disabled for get_treatment' do
          expect(subject.get_treatment('21', "sample_feature")).to eq('off')

          expect(impressions).to eq([])
        end
      end

      context 'traffic allocations' do
        before do
          stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
            .to_return(status: 200, body: traffic_allocation_json)
        end

        it 'returns expected treatment' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI')).to eq('off')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI')).to eq('off')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI')).to eq('off')
        end

        it 'returns expected treatment when traffic alllocation < 100' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI3')).to eq('off')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI3')).to eq('off')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI3')).to eq('off')
        end

        it 'returns expected treatment when traffic alllocation is 0' do
          expect(subject.get_treatment('01', 'Traffic_Allocation_UI4')).to eq('on')
          expect(subject.get_treatment('ab', 'Traffic_Allocation_UI4')).to eq('on')
          expect(subject.get_treatment('00b0', 'Traffic_Allocation_UI4')).to eq('on')
        end

        it 'returns "not in split" label' do
          subject.get_treatment('test', 'Traffic_Allocation_UI2')
          impressions_repository = subject.instance_variable_get(:@impressions_repository)

          expect(impressions_repository.clear[0][:impressions]['label']).to eq(Label::NOT_IN_SPLIT)
        end
      end
    end

    describe 'client destroy' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      it 'returns control' do
        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'on'

        subject.instance_variable_get(:@config).threads[:impressions_sender] = Thread.new {}
        subject.destroy

        expect(subject.get_treatment('fake_user_id_1', 'test_feature')).to eq 'control'
      end
    end

    describe 'redis outage' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      it 'returns control' do
        allow(subject.instance_variable_get(:@impressions_repository))
          .to receive(:add).and_raise(Redis::CannotConnectError)

        expect { subject.store_impression('', '', '', {}, '', '') }.not_to raise_error
      end
    end

    describe 'events' do
      before do
        stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
          .to_return(status: 200, body: all_keys_matcher_json)
      end

      let(:split_config) { SplitIoClient::SplitConfig.new }

      it 'fetches and deletes events' do
        subject.track('key', 'traffic_type', 'event_type', 'value')

        event = subject.instance_variable_get(:@events_repository).clear.first

        expect(event[:m]).to eq(
          s: "#{split_config.language}-#{split_config.version}",
          i: split_config.machine_ip,
          n: split_config.machine_name
        )

        expect(event[:e].reject { |e| e == :timestamp }).to eq(
          key: 'key',
          trafficTypeName: 'traffic_type',
          eventTypeId: 'event_type',
          value: 'value',
        )

        expect(subject.instance_variable_get(:@events_repository).clear).to eq([])
      end
    end
  end
end

describe SplitIoClient do
  include_examples 'engine specs', :memory
end

describe SplitIoClient do
  include_examples 'engine specs', :redis
end
