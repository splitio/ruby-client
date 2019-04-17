module SplitIoClient
  module LocalhostUtils

    require 'yaml'
    #
    # method to set localhost mode features by reading the given .splits
    #
    # @param splits_file [File] the .split file that contains the splits
    # @param reload_rate [Integer] the number of seconds to reload splits_file
    # @return nil
    def load_localhost_mode_features(splits_file, reload_rate = nil)
      return @localhost_mode_features unless File.exists?(splits_file)

      store_features(splits_file)

      return unless reload_rate

      Thread.new do
        loop do
          @localhost_mode_features = []
          store_features(splits_file)

          sleep(SplitIoClient::Utilities.randomize_interval(reload_rate))
        end
      end
    end

    def store_features(splits_file)
      yaml_extensions = [".yml", ".yaml"]
      if yaml_extensions.include? File.extname(splits_file)
        store_yaml_features(splits_file)
      else
        store_plain_text_features(splits_file)
      end
    end

    private

    def store_plain_text_features(splits_file)
      File.open(splits_file).each do |line|
        feature, treatment = line.strip.split(' ')

        next if line.start_with?('#') || line.strip.empty?

        @localhost_mode_features << { feature: feature, treatment: treatment, key: nil, config: nil }
      end
    end

    def store_yaml_features(splits_file)
      YAML.load(File.read(splits_file)).each do |feature|
        feat_symbolized_keys = feature[feature.keys.first].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

        feat_symbolized_keys[:config] = feat_symbolized_keys[:config].to_json

        @localhost_mode_features << { feature: feature.keys.first }.merge(feat_symbolized_keys)
      end
    end
  end
end
