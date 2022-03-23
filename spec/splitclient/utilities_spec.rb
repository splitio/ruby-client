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
    hash = {}

    i = 1
    while i <= 6
      hash["mauro-#{i}"] = Set.new(['feature', 'feature-1'])
      i += 1
    end

    result = SplitIoClient::Utilities.split_bulk_to_send(hash, 3)

    expect(result.size).to eq 3
    expect(result[0].size).to eq 2
    expect(result[1].size).to eq 2
    expect(result[2].size).to eq 2
  end

  it 'split bulk of data - split in 4 bulks' do
    hash = {}

    i = 1
    while i <= 6
      hash["mauro-#{i}"] = 'feature-test'
      i += 1
    end

    result = SplitIoClient::Utilities.split_bulk_to_send(hash, 4)

    expect(result.size).to eq 4
    expect(result[0].size).to eq 2
    expect(result[1].size).to eq 2
    expect(result[2].size).to eq 1
    expect(result[3].size).to eq 1
  end
end
