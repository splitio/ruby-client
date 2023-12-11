# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::DependencyMatcher do
  let(:evaluator) { double }

  it 'matches' do
    allow(evaluator).to receive(:evaluate_feature_flag).with({ matching_key: 'foo', bucketing_key: 'bar' }, 'foo', nil)
                                      .and_return(treatment: 'yes')

    expect(described_class.new('foo', %w[on yes true], @split_logger)
          .match?(matching_key: 'foo', bucketing_key: 'bar', evaluator: evaluator)).to eq(true)
  end

  it 'does not match' do
    allow(evaluator).to receive(:evaluate_feature_flag).with({ matching_key: 'foo', bucketing_key: 'bar' }, 'foo', nil)
                                      .and_return(treatment: 'no')

    expect(described_class.new('foo', %w[on yes true], @split_logger)
          .match?(matching_key: 'foo', bucketing_key: 'bar', evaluator: evaluator)).to eq(false)
  end

  it 'is not string type matcher' do
    expect(described_class.new('foo', %w[on yes true], @split_logger).string_type?).to be false
  end
end
