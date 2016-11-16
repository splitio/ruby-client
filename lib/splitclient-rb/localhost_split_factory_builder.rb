module SplitIoClient
  class LocalhostSplitFactoryBuilder < NoMethodError
    def self.build(directory = nil)
      splits_file = File.join(directory || Dir.home, ".split")
      LocalhostSplitFactory.new(splits_file)
    end

    def self.build_from_path(path)
      splits_file = File.join(path)
      LocalhostSplitFactory.new(splits_file)
    end
  end
end
