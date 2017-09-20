require 'spec_helper'

# describe SplitIoClient::AttributeMatcher do
#   let(:condition) do
#     SplitIoClient::Condition.new(
#       matcherGroup: { matchers: [{ keySelector: { attribute: '' }}]},
#       partitions: []
#     )
#   end
#
#   describe 'equal to matcher' do
#     context 'with key' do
#       let(:matcher) { SplitIoClient::StartsWithMatcher.new(nil, %w(val)) }
#
#       it 'matches' do
#         expect(described_class.new(nil, matcher).match?('value')).to eq(true)
#       end
#
#       it 'does not match' do
#         expect(described_class.new(nil, matcher).match?('vvalue')).to eq(false)
#       end
#     end
#
#     context 'with attribute' do
#       let(:matcher) { SplitIoClient::StartsWithMatcher.new(nil, %w(val)) }
#
#       it 'matches' do
#         expect(described_class.new(condition, matcher).match?('key', nil, nil, attr: 'value')).to eq(true)
#       end
#
#       it 'does not match' do
#         expect(described_class.new(condition, matcher).match?('key', nil, nil, attr: 'vvalue')).to eq(false)
#       end
#     end
#   end
#
#   describe 'ends with matcher' do
#     context 'with key' do
#       let(:matcher) { SplitIoClient::EndsWithMatcher.new(nil, %w(ue)) }
#
#       it 'matches' do
#         expect(described_class.new(nil, matcher).match?('value')).to eq(true)
#       end
#
#       it 'does not match' do
#         expect(described_class.new(nil, matcher).match?('valuee')).to eq(false)
#       end
#     end
#
#     context 'with attribute' do
#       let(:matcher) { SplitIoClient::EndsWithMatcher.new(nil, %w(ue)) }
#
#       it 'matches' do
#         expect(described_class.new(condition, matcher).match?('key', nil, nil, attr: 'value')).to eq(true)
#       end
#
#       it 'does not match' do
#         expect(described_class.new(condition, matcher).match?('key', nil, nil, attr: 'valuee')).to eq(false)
#       end
#     end
#   end
# end
