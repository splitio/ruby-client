# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the combining matcher
  #
  class CombiningMatcher < Matcher
    MATCHER_TYPE = 'COMBINING_MATCHER'

    def initialize(logger, combiner = '', matchers = [])
      super(logger)
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
      if @matchers.empty?
        @logger.log_if_debug('[CombiningMatcher] Matchers Empty')
        return false
      end

      case @combiner
      when Combiners::AND
        matches = eval_and(args)
        @logger.log_if_debug("[CombiningMatcher] Combiner AND result -> #{matches}")
        return matches
      else
        @logger.log_if_debug("[CombiningMatcher] Invalid Combiner Type - Combiner -> #{@combiner}")
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
      args[:attributes] = args[:attributes].each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v } if args && args[:attributes]

      @matchers.all? do |matcher|
        if match_with_key?(matcher)
          key = args[:value]
          key = args[:matching_key] unless args[:matching_key].nil?
          matcher.match?(value: key)
        else
          matcher.match?(args)
        end
      end
    end

    def match_with_key?(matcher)
      matcher.respond_to?(:attribute) && matcher.attribute.nil? && matcher.string_type?
    end

    #
    # function to print string value for this matcher
    #
    # @return [string] string value of this matcher
    def to_s
      @matcher_list.map(&:to_s).join("#{@combiner} ")
    end
  end
end
