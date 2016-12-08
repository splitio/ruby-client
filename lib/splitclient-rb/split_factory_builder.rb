require 'logger'

module SplitIoClient
  class SplitFactoryBuilder
    def self.build(api_key, config = {})
      case api_key
      when 'localhost'
        splits_file = config[:path]? config[:path] : File.join(Dir.home, '.split')

        LocalhostSplitFactory.new(splits_file, config[:reload_rate])
      else
        SplitFactory.new(api_key, config)
      end
    end
  end
end
