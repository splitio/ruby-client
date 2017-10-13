module SplitIoClient
  #
  # class to implement the combining matcher
  #
  class CombiningMatcher
    MATCHER_TYPE = 'COMBINING_MATCHER'.freeze

    def initialize(combiner = '', matchers = [])
      @combiner = combiner
      @matchers = matchers
    end

    #
    # evaluates if the key matches the matchers within the combiner
    #
    # @param matching_key [string] key value to be matched
    # @param bucketing_key [string] bucketing key to be matched
    # @param evaluator [instance of Evaluator class]
    # @param attributes [hash]
    #
    # @return [boolean]
    def match?(args)
      return false if @matchers.empty?

      case @combiner
      when Combiners::AND
        return eval_and(args)
      else
        @logger.error('Invalid combiner type')
      end

      false
    end

    #
    # auxiliary method to evaluate each of the matchers within the combiner
    #
    # @param matching_key [string] key value to be matched
    # @param bucketing_key [string] bucketing key to be matched
    # @param evaluator [Evaluator] used in dependency_matcher
    # @param attributes [hash]  attributes to pass to the treatment class
    #
    # @return [boolean] match value for combiner delegates
    def eval_and(args)
      # Convert all keys to symbols
      args[:attributes] = args[:attributes].inject({}){ |memo, (k,v)| memo[k.to_sym] = v; memo } if args && args[:attributes]
      @matchers.all? do |matcher|
        if match_with_key?(matcher)
          matcher.match?(value: args[:matching_key])
        else
          matcher.match?(args)
        end
      end
    end

    def match_with_key?(matcher)
      matcher.respond_to?(:attribute) && matcher.attribute.nil? && matcher.string_type?
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
      @matcher_list.map(&:to_s).join("#{@combiner} ")
    end
  end
end
