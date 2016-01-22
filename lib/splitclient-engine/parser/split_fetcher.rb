require "json"
require "thread"
require "faraday/http_cache"
require "bundler/vendor/net/http/persistent"


module SplitIoClient

  class SplitFetcher < NoMethodError

    # Creates a new split fetcher instance that consumes to split.io APIs
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config)

      @api_key = api_key
      @config = config
      @parsed_splits = SplitParser.new(@config.logger)
      @parsed_segments = SegmentParser.new(@config.logger)

      @api_client = Faraday.new do |builder|
        builder.use Faraday::HttpCache, store: @config.local_store
        builder.adapter :net_http_persistent
      end

      @consumer = create_api_consumer
    end

    def create_api_consumer
      Thread.new do
        loop do
          begin
            #splits fetch
            splits_arr = []
            data = get_splits(@parsed_splits.since)
            data[:splits].each do |split|
              splits_arr << SplitIoClient::Split.new(split)
            end

            if @parsed_splits.is_empty?
              @parsed_splits.splits = splits_arr
            else
              refresh_splits(splits_arr)
            end
            @parsed_splits.since = data[:till]

            #segments fetcher
            segments_arr =  []
            segment_data = get_segments(@parsed_splits.get_used_segments)
            segment_data.each do |segment|
              segments_arr << SplitIoClient::Segment.new(segment)
            end
            if @parsed_segments.is_empty?
              @parsed_segments.segments = segments_arr
            else
              refresh_segments(segments_arr)
            end

            sleep(@config.exec_interval)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end


    def call_api(path, params = {})
      @api_client.get @config.base_uri + path, params do |req|
        req.headers["Authorization"] = "Bearer " + @api_key
        req.options.open_timeout = @config.connection_timeout
        req.options.timeout = @config.timeout
      end
    end

    def get_splits(since)
      splits = call_api("/splitChanges", {:since => since})

      if splits.status / 100 == 2
        return JSON.parse(splits.body, symbolize_names: true)
      else
        @config.logger.error("Unexpected result from API call")
      end
    end

    def refresh_splits(splits_arr)
      feature_names = splits_arr.map{|s| s.name}
      @parsed_splits.splits.delete_if{|sp| feature_names.include?(sp.name)}
      @parsed_splits.splits += splits_arr
    end

    def get_segments(names)
      segments = []

      names.each do |name|
        curr_segment = @parsed_segments.get_segment(name)
        since = curr_segment.nil? ? -1 : curr_segment.since

        segment = call_api("/segmentChanges/" + name, {:since => since})

        if segment.status / 100 == 2
          segment_content = JSON.parse(segment.body, symbolize_names: true)
          @parsed_segments.since = segment_content[:since]
          segments << segment_content
        else
          @config.logger.error("Unexpected result from API call")
        end
      end

      return segments
    end

    def refresh_segments(segments_arr)
      segment_names = segments_arr.map{|s| s.name}
      @parsed_segments.segments.delete_if{|seg| segment_names.include?(seg.name)}
      @parsed_segments.segments += segments_arr
    end


    def parsed_splits
      @parsed_splits
    end

    def parsed_segments
      @parsed_segments
    end

  end
end