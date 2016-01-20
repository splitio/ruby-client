require 'splitclient-engine/matchers/combiners'

module SplitIoClient

  class CombiningMatcher < NoMethodError

    @matcher_list = []
    @combiner = ''

    def initialize(combiner, delegates)
      if !delegates.nil?
        @matcher_list = matcher
      end
      if !combiner.nil?
        @combiner = combiner
      end
    end

    def match?(key)
      if @matcher_list.empty?
        return false
      end

      case @combiner
        when Combiners::AND
          return and_eval(key)
        else
          #TODO throw error
      end
      !@matcher.match?(key)
    end

    def and_eval(key)
      result = true
      @matcher_list.each do |delegate|
        result &= (delegate.match?(key))
      end
      return result
    end

    def equals?(obj)
      if obj.nil?
        return false
      elsif !obj.instance_of?(CombiningMatcher)
        return false
      elsif this.equal?(obj)
        return true
      else
        return false
      end
    end

    def to_s
      result = ""
      @matcher_list.each_with_index do |matcher, i|
         result += matcher.to_s
         result += " " + @combiner if i != 0
      end
      return result
    end

  end

end