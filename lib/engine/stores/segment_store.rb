module SplitIoClient
  module Stores
    class SegmentStore
      def initialize(@cache, @config, @api_key)
        @cache = SplitIoClient::Cache::Split.new(adapter)
        @config = config
        @parsed_segments = SegmentParser.new(@config.logger)
        @api_key = api_key
      end

      def call
        Thread.new do
          loop do
            begin
              # segments_arr = []
              segment_data = segments_by_names(@parsed_splits.get_used_segments)
              segment_data.each do |segment|
                segments_arr << SplitIoClient::Segment.new(segment)
              end
              if @parsed_segments.is_empty?
                # FIXME
                @parsed_segments.segments = segments_arr
                @parsed_segments.segments.map { |s| s.refresh_users(s.added, s.removed) }
              else
                refresh_segments(segments_arr)
              end

              random_interval = randomize_interval @config.segments_refresh_rate
              sleep(random_interval)
            rescue StandardError => error
              @config.log_found_exception(__method__.to_s, error)
            end
          end
        end
      end
    end
  end
end
