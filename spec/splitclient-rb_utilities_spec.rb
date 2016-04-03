require 'spec_helper'

describe Utilities do

  describe "utilities epoch convertions returns correct values" do
    let(:string_date) { "2007-11-03 13:18:05 UTC" }
    let(:zero_second_string_date) { "2007-11-03 13:18 UTC" }

    it 'validates to_epoch method converts string dates to epoc in seconds removing seconds' do
      converted_to_seconds = Utilities.to_epoch(string_date)
      expect(converted_to_seconds).to eq(Time.parse(zero_second_string_date).to_i)
    end

    it 'validates to_epoch_milis method converts string dates to epoc in milis removing seconds' do
      converted_to_milis = Utilities.to_epoch_milis(string_date)
      expect(converted_to_milis).to eq ((Time.parse(zero_second_string_date).to_i)*1000)
    end

  end
end
