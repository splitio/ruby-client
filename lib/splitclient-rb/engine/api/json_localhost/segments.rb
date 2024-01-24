# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves segment changes from file system
    class SegmentsJSONLocalhost
      def initialize(segments_repository, config)
        @config = config
        @segments_repository = segments_repository
        @segment_directory = config.segment_directory
        @segments_sha = {}
      end

      def fetch_segments_by_names(segment_names, fetch_options=nil)
        return if segment_names.nil? || segment_names.empty?
        begin
          segment_names.each do |segment_name|
            segment = read_segment_from_json_file(segment_name)
            fetched_sha = Digest::SHA256.hexdigest(segment.to_s)

            if !@segments_repository.segment_exist?(segment_name)
              @segments_sha[segment_name] = fetched_sha
              @segments_repository.add_to_segment(segment)
              @segments_repository.set_change_number(segment_name, segment[:till])
              @config.logger.debug("\'#{segment_name}\' segment added.")
              return
            end

            return if fetched_sha == @segments_sha[segment_name]

            @segments_sha[segment_name] = fetched_sha
            return if @segments_repository.get_change_number(segment_name) > segment[:till] && segment[:till] != -1

            @segments_repository.add_to_segment(segment)
            @segments_repository.set_change_number(segment_name, segment[:till])
            @config.logger.debug("\'#{segment_name}\' segment is updated.")
          end
        rescue StandardError => e
          @config.logger.error("Exception synching segments: #{e.message}")
        end
      end

      private

      def read_segment_from_json_file(segment_name)
        begin
          @config.logger.debug("Syncing segment \'#{segment_name}\' from file system.")
          raise "Segment file does not exist" if !File.exists?(File.join(@segment_directory, segment_name))

          parsed = JSON.parse(File.read(File.join(@segment_directory, segment_name)), symbolize_names: true)
          santitized_segment = Helpers::ApiHelper.sanitize_segment(@config.logger, parsed)
        rescue StandardError => e
          @config.logger.error("Exception caught: #{e.message}")
          raise "Error parsing file for segment \'#{segment_name}\', Make sure it's readable."
        end
      end
    end
  end
end
