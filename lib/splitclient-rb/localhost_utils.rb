module SplitIoClient
  module LocalhostUtils
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
      File.open(splits_file).each do |line|
        feature, treatment = line.strip.split(' ')

        next if line.start_with?('#') || line.strip.empty?

        @localhost_mode_features << { feature: feature, treatment: treatment }
      end
    end
  end
end
