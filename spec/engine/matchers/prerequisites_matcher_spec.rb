# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::PrerequisitesMatcher do
  let(:evaluator) { double }

  it 'matches with empty prerequisites' do
    expect(described_class.new([], @split_logger)
          .match?(matching_key: 'foo', bucketing_key: 'bar', evaluator: evaluator)).to eq(true)
  end

  it 'matches with prerequisite treatments' do
    allow(evaluator).to receive(:evaluate_feature_flag).with({ matching_key: 'foo', bucketing_key: 'bar' }, 'flag1', nil)
                                      .and_return(treatment: 'on')

    expect(described_class.new([:n => 'flag1', :ts => ['on']], @split_logger)
          .match?(matching_key: 'foo', bucketing_key: 'bar', evaluator: evaluator)).to eq(true)
    expect(described_class.new([:n => 'flag1', :ts => ['off']], @split_logger)
          .match?(matching_key: 'foo', bucketing_key: 'bar', evaluator: evaluator)).to eq(false)
  end

  it 'is not string type matcher' do
    expect(described_class.new([], @split_logger).string_type?).to be false
  end
end
