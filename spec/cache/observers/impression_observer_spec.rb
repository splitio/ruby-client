# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Observers::ImpressionObserver do
  subject { SplitIoClient::Observers::ImpressionObserver }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:ip) { config.machine_ip }
  let(:machine_name) { config.machine_name }
  let(:version) { "#{config.language}-#{config.version}" }
  let(:impression_data1) do
    {
      k: 'matching_key',
      b: 'bucketing_key',
      f: 'split_name',
      t: 'treatment',
      r: 'label',
      c: 1_533_177_602_748,
      m: 1_478_113_516_002,
      pt: nil
    }
  end

  let(:impression_data2) do
    {
      k: 'matching_key_2',
      b: 'bucketing_key',
      f: 'split_name',
      t: 'treatment',
      r: 'label',
      c: 1_533_177_602_748,
      m: 1_478_113_516_022,
      pt: nil
    }
  end

  context 'test_and_set' do
    before do
      @impression_observer = subject.new
    end

    it 'first time should be nil and after that always return previous time' do
      result1 = @impression_observer.test_and_set(impression_data1)
      expect(result1).to be_nil

      # should return previous time
      impression_data1[:m] = 1_478_113_516_500
      result1 = @impression_observer.test_and_set(impression_data1)
      expect(result1).to eq(1_478_113_516_002)

      # should return new impression.time
      result1 = @impression_observer.test_and_set(impression_data1)
      expect(result1).to eq(1_478_113_516_500)

      # when impression.time < impression.pt should return the min.
      impression_data1[:m] = 1_478_113_516_001
      result1 = @impression_observer.test_and_set(impression_data1)
      expect(result1).to eq(1_478_113_516_001)

      # should return nil because is another impression
      result2 = @impression_observer.test_and_set(impression_data2)
      expect(result2).to be_nil

      # should return previous time
      result2 = @impression_observer.test_and_set(impression_data2)
      expect(result2).to eq(1_478_113_516_022)
    end

    it 'return nil because impression is nil' do
      result = @impression_observer.test_and_set(nil)
      expect(result).to be_nil
    end
  end
end
