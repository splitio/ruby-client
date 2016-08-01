require 'logger'
module SplitIoClient
  class SplitFactoryBuilder
    def self.build(api_key, config = {})
      @factory ||= SplitFactory.new(api_key, config)
    end
  end
end
