# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class SplitsJSONLocalhost
      def initialize(split_repository, config)
        @config = config
        @split_file = config.split_file
        @splits_sha = Digest::SHA256.hexdigest('')
        @split_repository = split_repository
      end

      def since(since = -1, fetch_options = {})
        begin
          fetched = read_feature_flags_from_json_file
          fetched_sha = Digest::SHA256.hexdigest(fetched.to_s)
          return {} if fetched_sha == @splits_sha
          @splits_sha = fetched_sha

          return {} if @split_repository.get_change_number > fetched[:till] && fetched[:till] != -1
#          result = splits_with_segment_names(fetched)
          unless fetched[:splits].empty?
            @config.logger.debug("#{fetched[:splits].length} feature flags retrieved. till=#{fetched[:till]}")
          end

          fetched
        rescue StandardError => e
          @config.logger.error("Exception synching feature flags: #{e.message}")
        end
      end

      private

      def splits_with_segment_names(parsed_splits)
        parsed_splits[:segment_names] =
          parsed_splits.each_with_object(Set.new) do |split, splits|
            splits << Helpers::Util.segment_names_by_feature_flag(split)
          end.flatten

        parsed_splits
      end

      def read_feature_flags_from_json_file
        begin
          @config.logger.debug("Syncing feature flags from file system.")
          raise "Feature flags file \'#{@split_file}\' does not exist" if !File.exists?(@split_file)

          parsed = JSON.parse(File.read(@split_file), symbolize_names: true)
          santitized = Helpers::ApiHelper.sanitize_feature_flag(@config, parsed)
          return santitized
        rescue StandardError => e
          @config.logger.error("Exception caught: #{e.message}")
          raise "Error parsing splits file \'#{@split_file}\', Make sure it's readable."
        end
      end
    end
  end
end
