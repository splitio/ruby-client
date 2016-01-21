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
            data = get_splits(@parsed_splits.since)
            if @parsed_splits.is_empty?
              @parsed_splits.splits = data[:splits]
            else
              refresh_splits(data[:splits])
            end
            @parsed_splits.since = data[:till]

            #segments fetcher
            segment_data = get_segments(@parsed_splits.get_used_segments)
            if @parsed_segments.is_empty?
              @parsed_segments.segments = segment_data
            else
              refresh_segments(segment_data)
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

      #data = { splits: [{name: 'uno', value: 'borix'},{name: 'dos', value: 'borix'},{name: 'tres', value: 'borix'}],
      #         since:-1, till:10 }
      #splits_arr = [{name: 'cuatro', value: 'borix'},{name: 'tres', value: 'borix-11'}]

      feature_names = splits_arr.map{|s| s[:name]}
      @parsed_splits.splits.delete_if{|sp| feature_names.include?(sp[:name])}
      @parsed_splits.splits += splits_arr

    end

    def get_segments(names)
      segments = []

      names.each do |name|
        curr_segment = @parsed_segments.get_segment(name) unless @parsed_segments.nil?
        since = curr_segment.nil? ? -1 : curr_segment[:since]

        segment = call_api("/segmentChanges/" + name, {:since => since})

        if segment.status / 100 == 2
          segment_content = JSON.parse(segment.body, symbolize_names: true)
          @parsed_segments.since = segment_content[:since]
          segments << segment_content
        else
          #TODO: log errors
          @config.logger.error("Unexpected result from API call")
        end
      end

      return segments
    end

    def refresh_segments(segments_arr)

      #data = { splits: [{name: 'uno', value: 'borix'},{name: 'dos', value: 'borix'},{name: 'tres', value: 'borix'}],
      #         since:-1, till:10 }
      #splits_arr = [{name: 'cuatro', value: 'borix'},{name: 'tres', value: 'borix-11'}]

      segment_names = segments_arr.map{|s| s[:name]}
      @parsed_segments.segments.delete_if{|seg| segment_names.include?(seg[:name])}
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