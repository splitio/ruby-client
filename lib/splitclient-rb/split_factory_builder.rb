require 'logger'

module SplitIoClient
  class SplitFactoryBuilder
    def self.build(api_key, config = {})
      case api_key
      when 'localhost'
        SplitIoClient.configure( { logger: config[:logger] } )

        LocalhostSplitFactory.new(split_file(config[:split_file]), config[:reload_rate])
      else
        SplitFactory.new(api_key, config)
      end
    end

    private

    def self.split_file(split_file_path)
      return split_file_path unless split_file_path.nil?

      SplitIoClient.configuration.logger.warn('Localhost mode: .split mocks ' \
        'will be deprecated soon in favor of YAML files, which provide more ' \
        'targeting power. Take a look in our documentation.')

      File.join(Dir.home, '.split')
    end
  end
end
