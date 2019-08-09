require 'logger'

module SplitIoClient
  class SplitFactoryBuilder
    def self.build(api_key, config = {})
      case api_key
      when 'localhost'
        configuration = SplitConfig.new(config)
        LocalhostSplitFactory.new(split_file(config[:split_file], configuration.logger), configuration, config[:reload_rate])
      else
        SplitFactory.new(api_key, config)
      end
    end

    private

    def self.split_file(split_file_path, logger)
      return split_file_path unless split_file_path.nil?

      logger.warn('Localhost mode: .split mocks ' \
        'will be deprecated soon in favor of YAML files, which provide more ' \
        'targeting power. Take a look in our documentation.')

      File.join(Dir.home, '.split')
    end
  end
end
