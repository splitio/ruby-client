module SplitIoClient
  class LocalhostSplitFactory
    attr_reader :client, :manager

    def initialize(splits_file, config, reload_rate = nil, logger = nil)
      @splits_file = splits_file
      @reload_rate = reload_rate
      @config = config

      @client = LocalhostSplitClient.new(@splits_file, @config, @reload_rate)
      @manager = LocalhostSplitManager.new(@splits_file, @reload_rate)
    end
  end
end
