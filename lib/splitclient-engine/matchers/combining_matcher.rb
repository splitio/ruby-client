require 'splitclient-engine/matchers/combiners'

module SplitIoClient

  class CombiningMatcher < NoMethodError

    @matcher_list = []
    @combiner = ''

    def initialize(combiner, delegates)
      unless delegates.nil?
        @matcher_list = delegates
      end
      unless combiner.nil?
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
    end

    def and_eval(key)
      result = true
      @matcher_list.each do |delegate|
        result &= (delegate.match?(key))
      end
      result
    end

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