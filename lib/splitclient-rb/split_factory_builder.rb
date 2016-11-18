module SplitIoClient
  class SplitFactoryBuilder
    def self.build(api_key, config = {})
      case api_key
      when 'localhost'
        splits_file = File.join(config[:path] || Dir.home, '.split')

        LocalhostSplitFactory.new(splits_file)
      else
        SplitFactory.new(api_key, config)
      end
    end
  end
end
