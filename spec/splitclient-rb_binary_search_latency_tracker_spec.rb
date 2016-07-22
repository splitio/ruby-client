require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('g3q5afinaih7veau8v6n7a7id9',{base_uri: 'http://localhost:8081/api/'}) }

  before :each do
    @tracker = SplitIoClient::BinarySearchLatencyTracker.new
    @tracker.clear
  end

  describe "Binary search accounts for the correct latency bucket" do
    it "Puts the latencies of <=1 millis or <= 1000 micros (less than first bucket) into the first bucket (index 0)" do
      @tracker.add_latency_micros(750)
      @tracker.add_latency_micros(450)
      expect(@tracker.get_latency(0)).to eq(2)

      @tracker.add_latency_millis(0)
      expect(@tracker.get_latency(0)).to eq(3)
    end

    it "Puts the latencies of 1 millis or <= 1000 micros into the first bucket (index 0)" do
      @tracker.add_latency_micros(1000)
      expect(@tracker.get_latency(0)).to eq(1)

      @tracker.add_latency_millis(1)
      expect(@tracker.get_latency(0)).to eq(2)
    end

    it "Puts the latencies of 7481 millis or 7481828 micros into the last bucket (index 22)" do
      @tracker.add_latency_micros(7481828)
      expect(@tracker.get_latency(22)).to eq(1)

      @tracker.add_latency_millis(7481)
      expect(@tracker.get_latency(22)).to eq(2)
    end

    it "Puts the latencies of more than 7481 millis or 7481828 micros into the last bucket (index 22)" do
        @tracker.add_latency_micros(7481830)
        expect(@tracker.get_latency(22)).to eq(1)

        @tracker.add_latency_micros(7999999)
        expect(@tracker.get_latency(22)).to eq(2)

        @tracker.add_latency_millis(7482)
        expect(@tracker.get_latency(22)).to eq(3)

        @tracker.add_latency_millis(8000)
        expect(@tracker.get_latency(22)).to eq(4)
    end

    it "Puts the latencies between 11,392 and 17,086 in the right bucket (8th bucket index 7)" do
        @tracker.add_latency_micros(11392)
        expect(@tracker.get_latency(7)).to eq(1)

        @tracker.add_latency_micros(17086)
        expect(@tracker.get_latency(7)).to eq(2)
    end

    it "Puts the boundary latencies of 1,499 and 1,500 in the right buckets (1st index 0 and 2nd index 1)" do
      @tracker.add_latency_micros(1499)
      expect(@tracker.get_latency(0)).to eq(1)

      @tracker.add_latency_micros(1500)
      expect(@tracker.get_latency(1)).to eq(1)
    end
  end
end
