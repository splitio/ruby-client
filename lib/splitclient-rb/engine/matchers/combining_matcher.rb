module SplitIoClient
  #
  # class to implement the combining matcher
  #
  class CombiningMatcher < NoMethodError

    #
    # list of matcher within the combiner
    #
    @matcher_list = []

    #
    # combiner value
    #
    @combiner = ''

    def initialize(combiner, delegates)
      unless delegates.nil?
        @matcher_list = delegates
      end
      unless combiner.nil?
        @combiner = combiner
      end
    end

    #
    # evaluates if the key matches the matchers within the combiner
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] match value for combiner delegates
    def match?(matching_key, bucketing_key, evaluator, attributes)
      if @matcher_list.empty?
        return false
      end

      case @combiner
        when Combiners::AND
          return and_eval(matching_key, bucketing_key, evaluator, attributes)
        else
          @logger.error('Invalid combiner type')
          return false
      end
    end

    #
    # auxiliary method to evaluate each of the matchers within the combiner
    #
    # @param key [string] key value to be matched
    # @param evaluator [Evaluator] used in dependency_matcher
    # @param attributes [hash]  attributes to pass to the treatment class
    #
    # @return [boolean] match value for combiner delegates
    def and_eval(matching_key, bucketing_key, evaluator, attributes)
      @matcher_list.each do |delegate|
        matched = delegate.match?(matching_key, bucketing_key, evaluator, attributes)

        return false unless matched
      end

      true
    end

    #
    # evaluates if the given object equals the matcher
    #
    # @param obj [object] object to be evaluated
    #
    # @returns [boolean] true if obj equals the matcher
    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(CombiningMatcher)
        false
      elsif self.equal?(obj)
        true
      else
        false
      end
    end

    #
    # function to print string value for this matcher
    #
    # @reutrn [string] string value of this matcher
    def to_s
      result = ''
      @matcher_list.each_with_index do |matcher, i|
        result += matcher.to_s
        result += ' ' + @combiner if i != 0
      end
      result
    end

  end

end
