module SplitIoClient


  class SplitClient < NoMethodError

    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = SplitConfig.default)

      @fetcher = SplitFetcher.new(api_key, config)

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
      #TODO : complete method

      parsed_splits = @fetcher.parsed_splits
      parsed_segments = @fetcher.parsed_segments

    end

    def get_experiment_treatment(id, experiment)
      return Treatments::CONTROL
    end


    def process(str)
      Treatments::CONTROL
      str = str.downcase
      str
    end

    private :get_treatment_without_exception_handling, :get_experiment_treatment

  end

end
