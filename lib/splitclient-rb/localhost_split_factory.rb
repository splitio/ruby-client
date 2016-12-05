module SplitIoClient
  class LocalhostSplitFactory
    attr_reader :client, :manager

    def initialize(splits_file, reload_rate = nil)
      @splits_file = splits_file
      @reload_rate = reload_rate

      @client = LocalhostSplitClient.new(@splits_file, @reload_rate)
      @manager = LocalhostSplitManager.new(@splits_file, @reload_rate)
    end
  end
end
