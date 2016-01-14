module SplitIoClient


  class SplitClient < NoMethodError

    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = SplitConfig.default)

      #@fetcher = SplitFetcher.new(api_key, config)
      @fetcher = SplitFetcher.new('ictlpssmv2rqhqb6b59fumq9lj', config)

    end

    # validates if a features should be on or off for the given user id
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [boolean]  true if feature is on, false otherwise
    def is_on?(id, feature)
      result = false

      begin
        treatment = get_treatment(id, feature)
        result = !Treatments.is_control?(treatment)
        return result
      rescue
        #TODO: Log error, do not throw exception
      end
      result
    end

    # obtains the treatment for a given feature
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [Treatment]  tretment constant value
    def get_treatment(id, feature)
      if id.nil?
        #TODO : log warn for null user id
        return Treatments::CONTROL
      end

      if feature.nil?
        return Treatments::CONTROL
      end

      begin
        treatment = get_treatment_without_exception_handling(id, feature)
        return treatment.nil? ? Treatments::CONTROL : treatment
      rescue
        #TODO : log error, do no throw exception
      end

      return Treatments::CONTROL
    end

    def get_treatment_without_exception_handling(id, feature)
      @fetcher.parsed_splits.segments = @fetcher.parsed_segments
      split = @fetcher.parsed_splits.get_split(feature)

      if split.nil?
        return Treatments::CONTROL
      else
        return @fetcher.parsed_splits.get_split_treatment(id, feature)
      end
    end

    def process(str)
      Treatments::CONTROL
      str = str.downcase
      str
    end

    def test
      @fetcher.parsed_splits.segments = @fetcher.parsed_segments
      puts @fetcher.parsed_splits.get_split('new_feature')
      puts "--------"
      puts @fetcher.parsed_splits.get_split('new_featurexx')
      puts "******************"
      @fetcher.parsed_splits.get_split_treatment(1,'new_feature')

    end

    private :get_treatment_without_exception_handling

  end

end
