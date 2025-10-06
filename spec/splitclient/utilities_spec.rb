# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Utilities do
  describe 'utilities epoch convertions returns correct values' do
    let(:string_date) { '2007-11-03 13:18:05 UTC' }
    let(:zero_second_string_date) { '2007-11-03 13:18 UTC' }

    it 'validates to_epoch method converts string dates to epoc in seconds removing seconds' do
      converted_to_seconds = SplitIoClient::Utilities.to_epoch(string_date)
      expect(converted_to_seconds).to eq(Time.parse(zero_second_string_date).to_i)
    end

    it 'validates to_epoch_milis method converts string dates to epoc in milis removing seconds' do
      converted_to_milis = SplitIoClient::Utilities.to_epoch_milis(string_date)
      expect(converted_to_milis).to eq Time.parse(zero_second_string_date).to_i * 1000
    end
  end

  it 'split bulk of data - split equally' do
    items = Set['feature', 'feature-1', 'feature-2', 'feature-3', 'feature-4', 'feature-5', 'feature-6']

    result = SplitIoClient::Utilities.split_bulk_to_send(items, 3)

    puts result
    expect(result.size).to eq 3
    expect(result[0].size).to eq 3
    expect(result[1].size).to eq 3
    expect(result[2].size).to eq 1
  end
end
