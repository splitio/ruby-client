# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactoryBuilder.build('localhost').client }

  let(:split_file) do
    ['local_feature local_treatment', 'local_feature2 local_treatment2', 'local_feature local_treatment_rewritten']
  end
  let(:split_file2) do
    ['local_feature local_treatment', 'local_feature2 local_treatment3', 'local_feature local_treatment_rewritten']
  end
  let(:split_string) do
    "local_feature local_treatment\nlocal_feature2 local_treatment2\local_feature local_treatment_rewritten"
  end

  describe '#get_treatment_with_config' do
    before do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:open).and_return(split_file)
      allow(File).to receive(:read).and_return(split_string)
    end

    let(:user_id_1) { 'my_random_user_id' }

    it 'returns corresponding treatment with nil config' do
      expect(subject.get_treatment_with_config(user_id_1, 'local_feature')).to eq(
        treatment: 'local_treatment_rewritten', config: nil
      )
    end
  end

  describe '#get_treatment returns localhost mode' do
    before do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:open).and_return(split_file)
      allow(File).to receive(:read).and_return(split_string)
    end

    let(:user_id_1) { 'my_random_user_id' }
    let(:user_id_2) { 'my_random_user_id' }
    let(:reloaded_factory) { SplitIoClient::SplitFactoryBuilder.build('localhost', reload_rate: 0.1).client }

    it 'validates the feature has the correct treatment for any user id in local mode' do
      # Also testing in the following expectation, that the last line of a repeated treatment prevails
      expect(subject.get_treatment(user_id_1, 'local_feature')).to eq('local_treatment_rewritten')
      expect(subject.get_treatment(user_id_2, 'local_feature2')).to eq('local_treatment2')
    end

    it 'validates a non existing feature has control as treatment for any user id in local mode' do
      expect(subject.get_treatment(user_id_1, 'weird_local_feature'))
        .to eq(SplitIoClient::Engine::Models::Treatment::CONTROL)
      expect(subject.get_treatment(user_id_2, 'non_existent_local_feature'))
        .to eq(SplitIoClient::Engine::Models::Treatment::CONTROL)
    end

    it 'receives updated features' do
      skip if RUBY_PLATFORM == 'java'
      expect(reloaded_factory.get_treatment(user_id_2, 'local_feature2')).to eq('local_treatment2')

      allow(File).to receive(:open).and_return(split_file2)

      sleep 0.2
      expect(reloaded_factory.get_treatment(user_id_2, 'local_feature2')).to eq('local_treatment3')
    end
  end

  context 'yaml file' do
    subject { SplitIoClient::SplitFactoryBuilder.build('localhost', split_file: split_file).client }

    let(:split_file) { File.expand_path(File.join(File.dirname(__FILE__), '../test_data/local_treatments/split.yaml')) }

    describe '#get_treatment' do
      it 'returns corresponding treatment based on key for multiple keys feature' do
        expect(subject.get_treatment('john_doe', 'multiple_keys_feature')).to eq('on')
        expect(subject.get_treatment('jane_doe', 'multiple_keys_feature')).to eq('on')
      end

      it 'defaults to no key treatment entry when key not found for multiple keys feature' do
        expect(subject.get_treatment('non_valid_key', 'multiple_keys_feature')).to eq('off')
      end

      it 'returns corresponding treatment based on key for single key feature' do
        expect(subject.get_treatment('john_doe', 'single_key_feature')).to eq('on')
      end

      it 'defaults to no key treatment entry when key not found for multiple keys feature' do
        expect(subject.get_treatment('non_valid_key', 'single_key_feature')).to eq('off')
      end

      it 'returns control treatment for invalid split_name' do
        expect(subject.get_treatment('any_key', 'invalid_feature')).to eq('control')
      end

      it 'returns control treatment for nil key' do
        expect(subject.get_treatment(nil, 'my_feature')).to eq('control')
      end

      it 'returns control treatment for empty key' do
        expect(subject.get_treatment('', 'my_feature')).to eq('control')
      end

      it 'returns control treatment for non hash or nil attributes' do
        expect(subject.get_treatment('john_doe', 'my_feature', 'attribute')).to eq('control')
      end

      it 'returns control treatment for nil split_name' do
        expect(subject.get_treatment('john_doe', nil)).to eq('control')
      end

      it 'returns control treatment for empty split_name' do
        expect(subject.get_treatment('john_doe', nil)).to eq('control')
      end

      it 'returns control treatment for numeric split_name' do
        expect(subject.get_treatment('john_doe', 1)).to eq('control')
      end
    end

    describe '#get_treatment_with_config' do
      it 'returns corresponding treatment and config based on key' do
        expect(subject.get_treatment_with_config('john_doe', 'multiple_keys_feature')).to eq(
          treatment: 'on',
          config: '{"desc":"this applies only to ON and only for john_doe and jane_doe. The rest will receive OFF"}'
        )
      end

      it 'defaults to no key treatment entry when key not found' do
        expect(subject.get_treatment_with_config('non_valid_key', 'multiple_keys_feature')).to eq(
          treatment: 'off', config: '{"desc":"this applies only to OFF treatment"}'
        )
      end

      it 'returns control treatment for invalid split_name' do
        expect(subject.get_treatment_with_config('any_key', 'invalid_feature')).to eq(treatment: 'control', config: nil)
      end
    end

    describe '#get_treatments' do
      it 'returns corresponding treatments' do
        expect(subject.get_treatments('john_doe', %w[multiple_keys_feature single_key_feature invalid_feature])).to eq(
          'multiple_keys_feature' => 'on',
          'single_key_feature' => 'on',
          'invalid_feature' => 'control'
        )
      end

      it 'returns nil if split names is nil' do
        expect(subject.get_treatments('john_doe', nil)).to be_nil
      end

      it 'returns empty hash if split names is empty' do
        expect(subject.get_treatments('john_doe', [])).to eq({})
      end
    end

    describe '#get_treatments_with_config' do
      it 'returns corresponding treatments' do
        expect(subject.get_treatments_with_config(
                 'john_doe', %w[multiple_keys_feature single_key_feature invalid_feature]
               )).to eq(
                 'multiple_keys_feature' => { treatment: 'on',
                                              config: '{"desc":"this applies only to ON and only for john_doe' \
                                               ' and jane_doe. The rest will receive OFF"}' },
                 'single_key_feature' => { treatment: 'on',
                                           config: '{"desc":"this applies only to ON and only for john_doe.' \
                                   ' The rest will receive OFF"}' },
                 'invalid_feature' => { treatment: 'control',
                                        config: nil }
               )
      end
    end
  end
end
